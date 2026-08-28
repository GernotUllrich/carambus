# frozen_string_literal: true

require "test_helper"

# Milestone v0.3 Plan 01-02 (nach UAT 2026-08-29 korrigiert):
# TableMonitorReflex#release_table — "Tisch freigeben" im Trainingsmodus.
#
# Der urspruengliche Knopf feuerte close_match. Das fuehrt nach :ready_for_new_match
# und laesst game_id ABSICHTLICH gesetzt ("previous game result still displayed here").
# Im Turnier ist das richtig, im Training folgte nichts mehr: Der Tisch blieb in
# diesem Zwischenzustand und galt in der Tischliste weiter als belegt
# (scoreboard_tables.html.erb prueft game.present?).
#
# release_table finalisiert vorsorglich und ruft dann reset_table_monitor —
# force_ready! + game_id: nil, OHNE das Game zu loeschen.
#
# Test-Pattern wie table_monitor_reflex_test.rb: Reflex via .allocate,
# morph/element gestubbt, TableMonitor.find auf die Test-Instanz gestubbt.
class TableMonitorReleaseTableReflexTest < ActiveSupport::TestCase
  fixtures :players

  setup do
    @game = Game.create!(id: Game::MIN_ID + 4242, tournament_id: nil, data: {}, gname: "rel_reflex")
    GameParticipation.create!(game: @game, player: players(:jaspers), role: "playera")
    GameParticipation.create!(game: @game, player: players(:cho), role: "playerb")

    @tm = TableMonitor.create!(
      state: "final_match_score", game: @game,
      data: {
        "playera" => {"result" => 30, "innings" => 20, "hs" => 6, "balls_goal" => 30},
        "playerb" => {"result" => 18, "innings" => 20, "hs" => 4, "balls_goal" => 30},
        "innings_goal" => 0, "allow_follow_up" => false
      }
    )
    @tm.define_singleton_method(:locked_scoreboard) { false }

    @reflex = TableMonitorReflex.allocate
    @reflex.define_singleton_method(:morph) { |_target| nil }
    @reflex.define_singleton_method(:element) { OpenStruct.new(dataset: {id: 1}) }
  end

  teardown do
    TableMonitor.where("created_at > ?", 1.minute.ago).destroy_all
    Game.where("created_at > ?", 1.minute.ago).destroy_all
  end

  test "release_table gibt den Tisch wirklich frei und behaelt das Spiel" do
    TableMonitor.stub(:find, @tm) { @reflex.release_table }
    @tm.reload

    assert_equal "ready", @tm.state, "der Tisch muss frei sein, nicht ready_for_new_match"
    assert_nil @tm.game_id, "game_id muss NULL sein — sonst gilt der Tisch als belegt"
    assert Game.exists?(@game.id), "das Spiel darf NICHT geloescht werden"
    assert_equal 2, Game.find(@game.id).game_participations.count
  end

  test "release_table ist im Turniermodus ein No-op" do
    @tm.define_singleton_method(:tournament_monitor) { TournamentMonitor.new }

    TableMonitor.stub(:find, @tm) { @reflex.release_table }

    assert_equal "final_match_score", @tm.reload.state, "Turnierpfad bleibt unveraendert"
    assert_equal @game.id, @tm.game_id
  end

  test "release_table respektiert locked_scoreboard" do
    @tm.define_singleton_method(:locked_scoreboard) { true }

    TableMonitor.stub(:find, @tm) { @reflex.release_table }

    assert_equal "final_match_score", @tm.reload.state, "gesperrtes Scoreboard darf nicht freigegeben werden"
    assert_equal @game.id, @tm.game_id
  end
end
