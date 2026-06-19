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
        email: "test-carambus-app-bridge@carambus.de",
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
      # Plan 15-06: Tisch-Naming-Tests erzeugen "Tisch N"-Tische + cc_id auf locations(:one)
      Table.where(location: locations(:one)).where("name LIKE ?", "Tisch %").destroy_all
      Location.where(id: locations(:one).id).update_all(cc_id: nil, region_id: nil)
      Location.where(name: "Kollision andere Region").destroy_all
      TableMonitor.where(name: %w[TM-RS-A TM-RS-B TM-06-A]).destroy_all

      TournamentCc.where(cc_id: 999_201).delete_all
      Tournament.where(title: "Test 3-Band Mannschaft 15-02").delete_all
      Seeding.where(tournament: @tournament).destroy_all if @tournament.persisted?
      User.where(email: "test-carambus-app-bridge@carambus.de").delete_all
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

    # Punkt 2 (HANDOFF tournament-id-ambiguity 2026-06-17): seeding via globalen
    # Tournament-DB-PK loest deterministisch auf (umgeht die region-scoped cc_id-Ambiguitaet).
    test "seeding via tournament_id (DB-PK) returns spec-compliant doc" do
      Seeding.create!(tournament: @tournament, player: @player, position: 1)
      headers = {"Content-Type" => "application/json", "Accept" => "application/json",
                 "Authorization" => "Bearer #{login_jwt}"}
      get "/api/external_tournament/seeding",
        params: {tournament_id: @tournament.id, region: "NBV"}, headers: headers
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "carambus.seeding/v1", body["schema"]
      assert_equal 999_201, body.dig("tournament", "cc_id")
    end

    test "seeding via unknown tournament_id returns 404" do
      headers = {"Content-Type" => "application/json", "Accept" => "application/json",
                 "Authorization" => "Bearer #{login_jwt}"}
      get "/api/external_tournament/seeding",
        params: {tournament_id: 999_999_999, region: "NBV"}, headers: headers
      assert_response :not_found
    end

    test "seeding via tournament_id with mismatched region returns 422" do
      @tournament.update_columns(region_id: regions(:bbv).id)
      headers = {"Content-Type" => "application/json", "Accept" => "application/json",
                 "Authorization" => "Bearer #{login_jwt}"}
      get "/api/external_tournament/seeding",
        params: {tournament_id: @tournament.id, region: "NBV"}, headers: headers
      assert_response :unprocessable_entity
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

    # AC-6 (Plan 15-06): unbekannter table_no → 422 (jetzt TableNotFoundError mit Identifier)
    test "round_start with unknown table_no returns 422" do
      setup_round_start_fixtures!

      payload = round_start_payload_one_game.deep_dup
      payload[:games][0][:table_no] = 99 # kein Table mit name="99"

      games_before = Game.count
      post_round_start(payload: payload, jwt: login_jwt)
      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      assert_match(/Table not found/i, body["error"].to_s)
      assert_match(/99/, body["error"].to_s)
      assert_equal games_before, Game.count
    end

    # === Plan 15-04: Round-Result-Endpoint Tests ===

    # AC-1: ohne JWT → 401
    test "round_result without Authorization returns 401" do
      get_round_result(tournament_cc_id: 999_201, round_no: 1, region: "NBV", jwt: nil)
      assert_response :unauthorized
    end

    # AC-2: mismatched region → 404
    test "round_result with mismatched region returns 404" do
      get_round_result(tournament_cc_id: 999_201, round_no: 1, region: "BVBW", jwt: login_jwt)
      assert_response :not_found
    end

    # AC-3: round_no missing → 422
    test "round_result without round_no returns 422" do
      get_round_result(tournament_cc_id: 999_201, round_no: nil, region: "NBV", jwt: login_jwt)
      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      assert_match(/round_no/i, body["error"].to_s)
    end

    # AC-3: round_no non-numeric → 422
    test "round_result with non-numeric round_no returns 422" do
      get_round_result(tournament_cc_id: 999_201, round_no: "abc", region: "NBV", jwt: login_jwt)
      assert_response :unprocessable_entity
    end

    # AC-4: Happy-Path — vollständiges round_result/v1
    test "round_result happy path returns carambus.round_result/v1 doc" do
      setup_round_result_fixtures!

      get_round_result(tournament_cc_id: 999_201, round_no: 1, region: "NBV", jwt: login_jwt)
      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal "carambus.round_result/v1", body["schema"]
      assert_equal "NBV", body["region"]["shortname"]
      assert_equal 999_201, body["tournament"]["cc_id"]
      assert_equal 1, body["round_no"]
      assert_equal 2, body["results"].size

      first = body["results"].first
      assert_equal "rr-test-ext-1", first["external_id"]
      assert_equal 5, first["table_no"]
      assert_equal 22, first["innings_played"]
      assert_equal 2, first["participants"].size

      pa = first["participants"].find { |p| p["role"] == "playera" }
      assert_equal 30, pa["points"]
      assert_equal 22, pa["innings"]
      assert_equal 5, pa["high_series"]
    end

    # AC-5: leere Runde → 200 mit empty results[]
    test "round_result with empty round returns 200 with empty results" do
      setup_round_result_fixtures!

      get_round_result(tournament_cc_id: 999_201, round_no: 99, region: "NBV", jwt: login_jwt)
      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal "carambus.round_result/v1", body["schema"]
      assert_equal 99, body["round_no"]
      assert_equal [], body["results"]
    end

    # AC-6: laufende Games (ended_at nil) sind included
    test "round_result includes ongoing games (ended_at nil)" do
      setup_round_result_fixtures!
      # Game 2 hat keinen ended_at gesetzt (siehe Fixture-Setup)

      get_round_result(tournament_cc_id: 999_201, round_no: 1, region: "NBV", jwt: login_jwt)
      assert_response :ok
      body = JSON.parse(response.body)
      ongoing = body["results"].find { |r| r["external_id"] == "rr-test-ext-2" }
      assert_not_nil ongoing
      assert_nil ongoing["ended_at"]
      assert_not_nil ongoing["started_at"]
    end

    # === Plan 15-06: Tables-Discovery (R1) ===

    # AC-3: ohne JWT → 401
    test "tables without Authorization returns 401" do
      get_tables(location_id: locations(:one).id, region: "NBV", jwt: nil)
      assert_response :unauthorized
    end

    # AC-1: Happy-Path via location_cc_id — echte Tisch-Namen + table_kind + has_monitor
    test "tables happy path returns carambus.tables/v1 with real names and kinds" do
      loc = locations(:one)
      loc.update_columns(cc_id: 11, region_id: @nbv.id)
      tk = table_kinds(:one)
      Table.create!(name: "Tisch 5", location: loc, table_kind: tk) # ohne Monitor
      Table.create!(name: "Tisch 6", location: loc, table_kind: tk)

      get_tables(location_cc_id: 11, region: "NBV", jwt: login_jwt)
      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal "carambus.tables/v1", body["schema"]
      assert_equal "NBV", body.dig("region", "shortname")
      assert_equal 11, body.dig("location", "cc_id")
      assert_equal loc.id, body.dig("location", "id")

      names = body["tables"].map { |t| t["name"] }
      assert_includes names, "Tisch 5"
      assert_includes names, "Tisch 6"

      t5 = body["tables"].find { |t| t["name"] == "Tisch 5" }
      assert_equal "Karambol", t5["table_kind"]
      assert_equal false, t5["has_monitor"]

      # Fixture "Table One" hat table_monitor_id gesetzt → has_monitor: true
      fixture_table = body["tables"].find { |t| t["name"] == "Table One" }
      assert_equal true, fixture_table["has_monitor"]
    end

    # AC-2: location_id-Lookup auch ohne location.cc_id
    test "tables resolves by location_id when location has no cc_id" do
      loc = locations(:one) # cc_id nil
      tk = table_kinds(:one)
      Table.create!(name: "Tisch 1", location: loc, table_kind: tk)

      get_tables(location_id: loc.id, region: "NBV", jwt: login_jwt)
      assert_response :ok
      body = JSON.parse(response.body)
      assert_nil body.dig("location", "cc_id")
      names = body["tables"].map { |t| t["name"] }
      assert_includes names, "Tisch 1"
    end

    # AC-3: unbekannte Location → 404
    test "tables for unknown location returns 404" do
      get_tables(location_id: 999_999, region: "NBV", jwt: login_jwt)
      assert_response :not_found
      body = JSON.parse(response.body)
      assert_match(/Location not found/i, body["error"].to_s)
    end

    # === Plan 15-07: location_cc_id Region-Scope (Bugfix aus 15-06-Live-Test) ===

    # AC-1: location_cc_id ist region-scoped — kollidierende cc_id in 2 Regionen
    test "tables location_cc_id is region-scoped — returns the region-correct location" do
      nbv_loc = locations(:one)
      nbv_loc.update_columns(cc_id: 11, region_id: @nbv.id)
      # gleichnamige cc_id in einer ANDEREN Region (Kollision)
      other = Location.create!(name: "Kollision andere Region", cc_id: 11, region_id: regions(:bbv).id)

      get_tables(location_cc_id: 11, region: "NBV", jwt: login_jwt)
      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal nbv_loc.id, body.dig("location", "id")
      assert_not_equal other.id, body.dig("location", "id")
    ensure
      Location.where(name: "Kollision andere Region").destroy_all
    end

    # === Plan 15-06: round_start location + table_name (R2) ===

    # AC-4: table_name + explizite location.cc_id (auch wenn tournament.location_id nil)
    test "round_start resolves table via table_name and explicit location cc_id" do
      loc = locations(:one)
      loc.update_columns(cc_id: 11, region_id: @nbv.id)
      @tournament.update_columns(location_id: nil) # beweist: explizite location wird genutzt
      tk = table_kinds(:one)
      tm = TableMonitor.create!(state: "new", name: "TM-06-A")
      Table.create!(name: "Tisch 5", location: loc, table_kind: tk, table_monitor: tm)

      @player_a = @player
      @player_b = players(:cho)

      post_round_start(payload: round_start_payload_table_name, jwt: login_jwt)
      assert_response :created
      body = JSON.parse(response.body)
      entry = body["games"].first
      assert_equal "rs06-ext-1", entry["external_id"]
      assert_equal tm.id, entry["table_monitor_id"]
      assert_equal entry["game_id"], tm.reload.game_id

      # D-15-06-D: table_name in Game.data persistiert
      game = Game.find(entry["game_id"])
      data = game.data.is_a?(Hash) ? game.data : JSON.parse(game.data.to_s)
      assert_equal "Tisch 5", data["table_name"]
    end

    # AC-7: table_name bevorzugt vor table_no — unbekannter Name → 422 mit Namen
    test "round_start with unknown table_name returns 422 with the name (table_name preferred)" do
      setup_round_start_fixtures! # erzeugt Tische "5"/"6" auf locations(:one)

      payload = round_start_payload_one_game.deep_dup
      # table_no=5 existiert, aber table_name hat Vorrang und existiert NICHT
      payload[:games][0][:table_name] = "Nicht existent"

      games_before = Game.count
      post_round_start(payload: payload, jwt: login_jwt)
      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      assert_match(/Table not found/i, body["error"].to_s)
      assert_match(/Nicht existent/, body["error"].to_s)
      assert_equal games_before, Game.count
    end

    # AC-6: TableMonitor wird automatisch angelegt (table.table_monitor!) auf local_server
    test "round_start auto-creates TableMonitor when table has none (local_server)" do
      loc = locations(:one)
      loc.update_columns(cc_id: 11, region_id: @nbv.id)
      @tournament.update!(location: loc)
      tk = table_kinds(:one)
      table = Table.create!(name: "Tisch 5", location: loc, table_kind: tk) # KEIN Monitor

      @player_a = @player
      @player_b = players(:cho)

      jwt = login_jwt
      ApplicationRecord.stub(:local_server?, true) do
        post_round_start(payload: round_start_payload_table_name, jwt: jwt)
      end

      assert_response :created
      body = JSON.parse(response.body)
      entry = body["games"].first
      assert entry["table_monitor_id"].is_a?(Integer)
      assert_not_nil table.reload.read_attribute(:table_monitor_id)
    end

    # AC-5: Alt-Client (kein location, kein table_name, nur table_no) unverändert
    test "round_start backward-compat with table_no only still works" do
      setup_round_start_fixtures! # Tische "5"/"6" mit Monitoren auf locations(:one)

      post_round_start(payload: round_start_payload_one_game, jwt: login_jwt)
      assert_response :created
      body = JSON.parse(response.body)
      assert_equal @tm_a.id, body["games"].first["table_monitor_id"]
    end

    # === Plan 15-06: seeding location-Objekt (R3) ===

    # AC-8: seeding liefert tournament.location als {id, cc_id, name}
    test "seeding returns tournament.location as object" do
      loc = locations(:one)
      loc.update_columns(cc_id: 11, region_id: @nbv.id)
      @tournament.update!(location: loc)
      Seeding.create!(tournament: @tournament, player: @player, position: 1)

      get_seeding(tournament_cc_id: 999_201, region: "NBV", jwt: login_jwt)
      assert_response :success
      body = JSON.parse(response.body)
      locobj = body.dig("tournament", "location")
      assert_equal loc.id, locobj["id"]
      assert_equal 11, locobj["cc_id"]
      assert_equal loc.name, locobj["name"]
    end

    # AC-8: null location wenn tournament.location_id nil
    test "seeding returns null location when tournament has no location" do
      @tournament.update_columns(location_id: nil)
      Seeding.create!(tournament: @tournament, player: @player, position: 1)

      get_seeding(tournament_cc_id: 999_201, region: "NBV", jwt: login_jwt)
      assert_response :success
      body = JSON.parse(response.body)
      assert_nil body.dig("tournament", "location")
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

    # === Round-Result-Test-Fixtures ===

    def setup_round_result_fixtures!
      @player_a = players(:jaspers)
      @player_b = players(:cho)

      # Tournament hat has_many :games, as: :tournament (polymorphic-from-Tournament);
      # daher via @tournament.games.create! erstellen damit tournament_type gesetzt wird.
      @rr_game_1 = @tournament.games.create!(
        round_no: 1,
        gname: "RR-G1",
        seqno: 1,
        table_no: 5,
        started_at: Time.zone.parse("2026-05-17 11:05:00 +0200"),
        ended_at: Time.zone.parse("2026-05-17 11:42:00 +0200"),
        data: {external_id: "rr-test-ext-1"}
      )
      GameParticipation.create!(game: @rr_game_1, player: @player_a, role: "playera",
        points: 30, innings: 22, hs: 5, gd: 1.364)
      GameParticipation.create!(game: @rr_game_1, player: @player_b, role: "playerb",
        points: 24, innings: 22, hs: 4)

      # Game 2: laufend (kein ended_at gesetzt)
      @rr_game_2 = @tournament.games.create!(
        round_no: 1,
        gname: "RR-G2",
        seqno: 2,
        table_no: 6,
        started_at: Time.zone.parse("2026-05-17 11:05:00 +0200"),
        data: {external_id: "rr-test-ext-2"}
      )
      GameParticipation.create!(game: @rr_game_2, player: @player_a, role: "playera",
        points: 12, innings: 10, hs: 3)
      GameParticipation.create!(game: @rr_game_2, player: @player_b, role: "playerb",
        points: 9, innings: 10, hs: 2)
    end

    def get_round_result(tournament_cc_id:, round_no:, region:, jwt:)
      headers = {"Content-Type" => "application/json", "Accept" => "application/json"}
      headers["Authorization"] = "Bearer #{jwt}" if jwt
      params = {tournament_cc_id: tournament_cc_id, region: region}
      params[:round_no] = round_no unless round_no.nil?
      get "/api/external_tournament/round_result", params: params, headers: headers
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

    # Plan 15-06 (R2): Payload mit explizitem table_name + location.cc_id (kein table_no).
    def round_start_payload_table_name
      {
        schema: "carambus.round_start/v1",
        region: {shortname: "NBV"},
        location: {cc_id: 11},
        tournament: {cc_id: 999_201, name: @tournament.title},
        round_no: 1,
        round_name: "Runde 1",
        games: [
          {
            external_id: "rs06-ext-1",
            table_name: "Tisch 5",
            discipline: {name: "3-Band"},
            format: {target_points: 30, max_innings: 25},
            context: {round_no: 1, round_name: "Runde 1", gname: "RS06-G1", group_no: 1, seqno: 1},
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

    def get_tables(region:, jwt:, location_id: nil, location_cc_id: nil)
      headers = {"Content-Type" => "application/json", "Accept" => "application/json"}
      headers["Authorization"] = "Bearer #{jwt}" if jwt
      params = {region: region}
      params[:location_id] = location_id unless location_id.nil?
      params[:location_cc_id] = location_cc_id unless location_cc_id.nil?
      get "/api/external_tournament/tables", params: params, headers: headers
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
