# frozen_string_literal: true

require "test_helper"

# Plan 15-03 Task 3b: Tests für ExternalTournament::RoundStartProcessor.
#
# Coverage:
#   - Game-Creation mit external_id in data
#   - Idempotenz (zweiter Aufruf gibt selben Game zurück, kein +Game-Count)
#   - PlayerResolutionError bei no-match
#   - TableMonitorNotFoundError bei Table.name-miss
#   - Transaction-Rollback bei Player-Error (kein partielles Game)
#   - Multi-Game-Payload erzeugt mehrere Games
module ExternalTournament
  class RoundStartProcessorTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @discipline = disciplines(:carom_3band)
      @season = seasons(:current)
      @location = locations(:one)

      @tournament = Tournament.create!(
        title: "Test RoundStartProcessor 15-03",
        region_id: @nbv.id,
        discipline: @discipline,
        season: @season,
        organizer: clubs(:bcw),
        location: @location,
        balls_goal: 30,
        innings_goal: 25,
        date: Time.zone.parse("2026-05-17 11:00:00 +0200")
      )

      @tm_a = TableMonitor.create!(state: "new", name: "TM-RSPT-A")
      @tm_b = TableMonitor.create!(state: "new", name: "TM-RSPT-B")
      @table_kind = table_kinds(:one)
      @table_a = Table.create!(name: "5", location: @location, table_monitor: @tm_a, table_kind: @table_kind)
      @table_b = Table.create!(name: "6", location: @location, table_monitor: @tm_b, table_kind: @table_kind)

      @player_a = players(:jaspers)
      @player_b = players(:cho)
    end

    teardown do
      if @tournament&.persisted?
        Game.where(tournament: @tournament).each do |g|
          GameParticipation.where(game_id: g.id).delete_all
          g.delete
        end
      end
      @table_a&.destroy
      @table_b&.destroy
      @tm_a&.destroy
      @tm_b&.destroy
      @tournament&.destroy
    end

    test "creates new Game with external_id stored in data" do
      processor = RoundStartProcessor.new(
        tournament: @tournament,
        region: @nbv,
        payload: payload_one_game("rspt-ext-1", 5)
      )

      games_before = Game.count
      result = processor.call

      assert_equal games_before + 1, Game.count
      assert_equal 1, result.games.size
      assert result.created_any?

      entry = result.games.first
      assert_equal "rspt-ext-1", entry[:external_id]

      game = Game.find(entry[:game_id])
      data = game.data.is_a?(Hash) ? game.data : JSON.parse(game.data.to_s)
      assert_equal "rspt-ext-1", data["external_id"]
      assert_equal 5, game.table_no
      assert_equal 1, game.round_no
    end

    test "is idempotent — second call returns existing Game without new records" do
      processor = RoundStartProcessor.new(
        tournament: @tournament,
        region: @nbv,
        payload: payload_one_game("rspt-idem", 5)
      )

      first_result = processor.call
      games_after_first = Game.count
      gps_after_first = GameParticipation.count

      processor2 = RoundStartProcessor.new(
        tournament: @tournament,
        region: @nbv,
        payload: payload_one_game("rspt-idem", 5)
      )
      second_result = processor2.call

      assert_equal first_result.games.first[:game_id], second_result.games.first[:game_id]
      assert_equal games_after_first, Game.count
      assert_equal gps_after_first, GameParticipation.count
      refute second_result.created_any?
    end

    test "raises PlayerResolutionError when participant cannot be matched" do
      payload = payload_one_game("rspt-noplayer", 5)
      payload[:games][0][:participants][0][:player] = {
        cc_id: 999_999_999, firstname: "Unknown", lastname: "Ghost"
      }

      processor = RoundStartProcessor.new(tournament: @tournament, region: @nbv, payload: payload)

      assert_raises(RoundStartProcessor::PlayerResolutionError) do
        processor.call
      end
    end

    test "raises TableMonitorNotFoundError when no Table.name matches" do
      payload = payload_one_game("rspt-notable", 99) # name="99" existiert nicht
      processor = RoundStartProcessor.new(tournament: @tournament, region: @nbv, payload: payload)

      assert_raises(RoundStartProcessor::TableMonitorNotFoundError) do
        processor.call
      end
    end

    test "transaction rolls back on player error — no partial Game creation" do
      payload = payload_one_game("rspt-rollback", 5)
      # Player B nicht matchbar (Player A wäre OK)
      payload[:games][0][:participants][1][:player] = {
        cc_id: 999_999_999, firstname: "Unknown", lastname: "Ghost"
      }

      processor = RoundStartProcessor.new(tournament: @tournament, region: @nbv, payload: payload)

      games_before = Game.count
      assert_raises(RoundStartProcessor::PlayerResolutionError) do
        processor.call
      end
      assert_equal games_before, Game.count, "Transaction should have rolled back the Game creation"
    end

    test "creates multiple Games + Participations across multi-game payload" do
      payload = {
        schema: "carambus.round_start/v1",
        region: {shortname: "NBV"},
        tournament: {cc_id: 999_201, name: @tournament.title},
        round_no: 2,
        round_name: "Runde 2",
        games: [
          one_game_hash("rspt-multi-1", 5, "RSPT-MG-1", 1),
          one_game_hash("rspt-multi-2", 6, "RSPT-MG-2", 2)
        ]
      }

      processor = RoundStartProcessor.new(tournament: @tournament, region: @nbv, payload: payload)

      games_before = Game.count
      gps_before = GameParticipation.count
      result = processor.call

      assert_equal 2, result.games.size
      assert_equal games_before + 2, Game.count
      assert_equal gps_before + 4, GameParticipation.count

      external_ids = result.games.map { |g| g[:external_id] }
      assert_includes external_ids, "rspt-multi-1"
      assert_includes external_ids, "rspt-multi-2"

      tm_ids = result.games.map { |g| g[:table_monitor_id] }
      assert_includes tm_ids, @tm_a.id
      assert_includes tm_ids, @tm_b.id
    end

    private

    def one_game_hash(external_id, table_no, gname, seqno)
      {
        external_id: external_id,
        table_no: table_no,
        discipline: {name: "3-Band"},
        format: {target_points: 30, max_innings: 25},
        context: {round_no: 1, round_name: "Runde 1", gname: gname, group_no: 1, seqno: seqno},
        participants: [
          {role: "playera", player: {cc_id: @player_a.cc_id || 9001, firstname: @player_a.firstname, lastname: @player_a.lastname}},
          {role: "playerb", player: {cc_id: @player_b.cc_id || 9002, firstname: @player_b.firstname, lastname: @player_b.lastname}}
        ]
      }
    end

    def payload_one_game(external_id, table_no)
      {
        schema: "carambus.round_start/v1",
        region: {shortname: "NBV"},
        tournament: {cc_id: 999_201, name: @tournament.title},
        round_no: 1,
        round_name: "Runde 1",
        games: [one_game_hash(external_id, table_no, "RSPT-G-#{external_id}", 1)]
      }
    end
  end
end
