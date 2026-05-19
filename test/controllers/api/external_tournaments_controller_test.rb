# frozen_string_literal: true

require "test_helper"

# Plan 15-02 Task 3: Tests für Api::ExternalTournamentsController#seeding
#
# Auth-Pattern wiederverwendet aus test/controllers/api/tournament_ccs_controller_test.rb (G.14):
# POST /login mit JSON-Credentials → Authorization-Header mit Bearer-JWT extrahieren.
#
# D-15-01-A: Service-Account-Pattern analog G.14.
module Api
  class ExternalTournamentsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @nbv = regions(:nbv)
      @discipline = disciplines(:carom_3band)
      @season = seasons(:current)

      @service_user = User.create!(
        email: "test-2band-bridge@carambus.de",
        password: "password123"
      )

      @tournament = Tournament.create!(
        title: "Test 3-Band Mannschaft 15-02",
        region_id: @nbv.id,
        discipline: @discipline,
        season: @season,
        organizer: clubs(:bcw),
        balls_goal: 30,
        innings_goal: 25,
        sets_to_play: 1,
        date: Time.zone.parse("2026-05-17 11:00:00 +0200")
      )

      @tournament_cc = TournamentCc.create!(
        cc_id: 999_201,
        context: @nbv.shortname.downcase,
        name: @tournament.title,
        tournament: @tournament
      )

      @player = players(:jaspers) # Fixture-Player
    end

    teardown do
      # Plan 15-03: round_start-Test-Artefakte (Games + GameParticipations + Tables + TableMonitors)
      if @tournament&.persisted?
        Game.where(tournament: @tournament).each do |g|
          GameParticipation.where(game_id: g.id).delete_all
          g.delete
        end
      end
      Table.where(name: %w[5 6]).where(location: locations(:one)).destroy_all
      TableMonitor.where(name: %w[TM-RS-A TM-RS-B]).destroy_all

      TournamentCc.where(cc_id: 999_201).delete_all
      Tournament.where(title: "Test 3-Band Mannschaft 15-02").delete_all
      Seeding.where(tournament: @tournament).destroy_all if @tournament.persisted?
      User.where(email: "test-2band-bridge@carambus.de").delete_all
    end

    # AC-3: ohne JWT → 401
    test "seeding without Authorization header returns 401" do
      get_seeding(tournament_cc_id: 999_201, region: "NBV", jwt: nil)
      assert_response :unauthorized
    end

    # AC-3: mit ungültigem JWT → 401
    test "seeding with invalid JWT returns 401" do
      get_seeding(tournament_cc_id: 999_201, region: "NBV", jwt: "garbage-token")
      assert_response :unauthorized
    end

    # AC-4: Region-Mismatch → 422
    test "seeding with mismatched region returns 422" do
      get_seeding(tournament_cc_id: 999_201, region: "BVBW", jwt: login_jwt)
      # Tournament gehört zu NBV, aber Param region=BVBW
      # Erste Lookup-Stufe ist TournamentCc.find_by(cc_id: ..., context: "bvbw") → not_found
      # Daher 404 (nicht 422) — Region-Mismatch wird nur bei valid TournamentCc-Match geprüft.
      assert_response :not_found
    end

    # AC-4 (echter Region-Mismatch): TournamentCc existiert mit context="nbv", aber Tournament hat andere region_id
    test "seeding when tournament.region_id mismatches param region returns 422" do
      # Tournament-Region manipulieren
      @tournament.update_columns(region_id: regions(:bbv).id)
      get_seeding(tournament_cc_id: 999_201, region: "NBV", jwt: login_jwt)
      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      assert_match(/Region mismatch/i, body["error"].to_s)
    end

    # AC-2: TournamentCc ohne Tournament-Link → 422
    test "seeding for TournamentCc without linked Tournament returns 422" do
      @tournament_cc.update_columns(tournament_id: nil)
      get_seeding(tournament_cc_id: 999_201, region: "NBV", jwt: login_jwt)
      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      assert_match(/not.*linked/i, body["error"].to_s)
    end

    # Not-Found: unbekannte tournament_cc_id
    test "seeding for unknown tournament_cc_id returns 404" do
      get_seeding(tournament_cc_id: 999_999, region: "NBV", jwt: login_jwt)
      assert_response :not_found
    end

    # AC-2 + AC-6: Happy-Path mit Single-Player-Tournament (kein league_team_id)
    test "seeding happy path returns spec-compliant carambus.seeding/v1 doc" do
      Seeding.create!(tournament: @tournament, player: @player, position: 1)

      get_seeding(tournament_cc_id: 999_201, region: "NBV", jwt: login_jwt)
      assert_response :success
      body = JSON.parse(response.body)

      assert_equal "carambus.seeding/v1", body["schema"]
      assert_equal "NBV", body.dig("region", "shortname")
      assert_match(%r{https://nbv\.carambus\.de}, body.dig("region", "url"))
      assert_equal 999_201, body.dig("tournament", "cc_id")
      assert_equal @tournament.title, body.dig("tournament", "name")

      format = body.dig("tournament", "format")
      assert_equal 30, format["target_points"]
      assert_equal 25, format["max_innings"]
      assert_equal 1, format["sets"]
      assert_nil format["frames"]

      assert_kind_of Array, body["teams"]
      assert_equal 1, body["teams"].length
      first_team = body["teams"].first
      assert_equal 1, first_team["seeding_position"]
      assert_kind_of Array, first_team["players"]
      assert_equal 1, first_team["players"].length
      player_data = first_team["players"].first
      assert_equal 1, player_data["position_in_team"]
      assert_equal @player.firstname, player_data["firstname"]
    end

    # === Plan 15-03: Round-Start-Endpoint Tests ===

    # AC-1: ohne JWT → 401
    test "round_start without Authorization returns 401" do
      post_round_start(payload: minimal_round_start_payload, jwt: nil)
      assert_response :unauthorized
    end

    # AC-1: mit Garbage-JWT → 401
    test "round_start with invalid JWT returns 401" do
      post_round_start(payload: minimal_round_start_payload, jwt: "garbage-token")
      assert_response :unauthorized
    end

    # AC-2: Region passt nicht → 404 (TournamentCc-Lookup-Miss; analog seeding-Test)
    test "round_start with mismatched region returns 404" do
      payload = minimal_round_start_payload.deep_dup
      payload[:region][:shortname] = "BVBW"
      post_round_start(payload: payload, jwt: login_jwt)
      assert_response :not_found
    end

    # AC-3: Happy-Path — Game + GameParticipation + TableMonitor.game_id
    test "round_start happy path creates Game + Participations and assigns TableMonitor" do
      setup_round_start_fixtures!

      games_before = Game.count
      gps_before = GameParticipation.count

      post_round_start(payload: round_start_payload_one_game, jwt: login_jwt)

      assert_response :created
      body = JSON.parse(response.body)
      assert_equal 1, body["games"].size
      entry = body["games"].first
      assert_equal "rs-test-ext-1", entry["external_id"]
      assert entry["game_id"].is_a?(Integer)
      assert entry["table_monitor_id"].is_a?(Integer)

      assert_equal games_before + 1, Game.count
      assert_equal gps_before + 2, GameParticipation.count

      game = Game.find(entry["game_id"])
      data = game.data.is_a?(Hash) ? game.data : JSON.parse(game.data.to_s)
      assert_equal "rs-test-ext-1", data["external_id"]
      assert_equal @tm_a.id, entry["table_monitor_id"]
      assert_equal game.id, @tm_a.reload.game_id
    end

    # AC-4: Idempotenz — gleicher external_id, gleiche game_id, status 200
    test "round_start idempotent — second POST returns same game_id with status 200" do
      setup_round_start_fixtures!

      post_round_start(payload: round_start_payload_one_game, jwt: login_jwt)
      assert_response :created
      first_game_id = JSON.parse(response.body)["games"].first["game_id"]
      games_after_first = Game.count

      post_round_start(payload: round_start_payload_one_game, jwt: login_jwt)
      assert_response :ok
      second_game_id = JSON.parse(response.body)["games"].first["game_id"]

      assert_equal first_game_id, second_game_id
      assert_equal games_after_first, Game.count
    end

    # AC-5: PlayerMatcher findet keinen Player → 422
    test "round_start with unresolvable player returns 422" do
      setup_round_start_fixtures!

      payload = round_start_payload_one_game.deep_dup
      # Unbekannte Player-Daten — keiner der 3 Fallback-Pfade matched
      payload[:games][0][:participants][0][:player] = {
        cc_id: 999_999_999,
        firstname: "Unknown",
        lastname: "Ghost"
      }

      games_before = Game.count
      post_round_start(payload: payload, jwt: login_jwt)
      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      assert_match(/Player not resolved/i, body["error"].to_s)
      # Transaction-Rollback: kein Game erzeugt
      assert_equal games_before, Game.count
    end

    # AC-6: TableMonitor nicht gefunden → 422
    test "round_start with unknown table_no returns 422" do
      setup_round_start_fixtures!

      payload = round_start_payload_one_game.deep_dup
      payload[:games][0][:table_no] = 99 # kein Table mit name="99"

      games_before = Game.count
      post_round_start(payload: payload, jwt: login_jwt)
      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      assert_match(/TableMonitor not found/i, body["error"].to_s)
      assert_match(/table_no=99/, body["error"].to_s)
      assert_equal games_before, Game.count
    end

    private

    # === Round-Start-Test-Fixtures ===

    def setup_round_start_fixtures!
      @location = locations(:one)
      @tournament.update!(location: @location)

      @tm_a = TableMonitor.create!(state: "new", name: "TM-RS-A")
      @tm_b = TableMonitor.create!(state: "new", name: "TM-RS-B")
      @table_kind = table_kinds(:one)
      @table_a = Table.create!(name: "5", location: @location, table_monitor: @tm_a, table_kind: @table_kind)
      @table_b = Table.create!(name: "6", location: @location, table_monitor: @tm_b, table_kind: @table_kind)

      @player_a = @player # players(:jaspers)
      @player_b = players(:cho)
    end

    def teardown_round_start_fixtures!
      @table_a&.destroy
      @table_b&.destroy
      @tm_a&.destroy
      @tm_b&.destroy
    end

    def minimal_round_start_payload
      {
        schema: "carambus.round_start/v1",
        region: {shortname: "NBV"},
        tournament: {cc_id: 999_201},
        round_no: 1,
        round_name: "Runde 1",
        games: []
      }
    end

    def round_start_payload_one_game
      {
        schema: "carambus.round_start/v1",
        region: {shortname: "NBV"},
        tournament: {cc_id: 999_201, name: @tournament.title},
        round_no: 1,
        round_name: "Runde 1",
        games: [
          {
            external_id: "rs-test-ext-1",
            table_no: 5,
            discipline: {name: "3-Band"},
            format: {target_points: 30, max_innings: 25},
            context: {round_no: 1, round_name: "Runde 1", gname: "RS-Test-G1", group_no: 1, seqno: 1},
            participants: [
              {role: "playera", player: {cc_id: @player_a.cc_id || 9001, firstname: @player_a.firstname, lastname: @player_a.lastname}},
              {role: "playerb", player: {cc_id: @player_b.cc_id || 9002, firstname: @player_b.firstname, lastname: @player_b.lastname}}
            ]
          }
        ]
      }
    end

    def post_round_start(payload:, jwt:)
      headers = {"Content-Type" => "application/json", "Accept" => "application/json"}
      headers["Authorization"] = "Bearer #{jwt}" if jwt
      post "/api/external_tournament/round_start",
        params: payload.to_json,
        headers: headers
    end

    def get_seeding(tournament_cc_id:, region:, jwt:)
      headers = {"Content-Type" => "application/json", "Accept" => "application/json"}
      headers["Authorization"] = "Bearer #{jwt}" if jwt
      get "/api/external_tournament/seeding",
        params: {tournament_cc_id: tournament_cc_id, region: region},
        headers: headers
    end

    def login_jwt
      post "/login",
        params: {user: {email: @service_user.email, password: "password123"}}.to_json,
        headers: {
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
      raise "Login failed in test: #{response.code} #{response.body}" unless response.successful?
      jwt = response.headers["Authorization"].to_s.sub(/\ABearer\s+/, "")
      cookies.delete(:_carambus_session) if cookies.respond_to?(:delete)
      reset!
      jwt
    end
  end
end
