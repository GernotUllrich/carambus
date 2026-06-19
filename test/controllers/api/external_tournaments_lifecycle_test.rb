# frozen_string_literal: true

require "test_helper"

# Plan 17-02: Controller-Tests fuer die neuen Lifecycle-Endpoints (tournament create, lock_table)
# + tables-Discovery-Erweiterung (locked_for_tournament). Auth-Muster wie Phase 15.
module Api
  class ExternalTournamentsLifecycleTest < ActionDispatch::IntegrationTest
    setup do
      @nbv = regions(:nbv)
      @location = locations(:one)
      @service_user = User.create!(email: "test-carambus-app-lifecycle@carambus.de", password: "password123")
      @player_a = Player.create!(id: 50_100_501, firstname: "AckCtrlA", lastname: "Test", dbu_nr: 43001, ba_id: 43001)
      @player_b = Player.create!(id: 50_100_502, firstname: "AckCtrlB", lastname: "Test", dbu_nr: 43002, ba_id: 43002)
    end

    teardown do
      GameParticipation.where(player: [@player_a, @player_b].compact).delete_all
      Tournament.where(region_id: @nbv.id, external_id: %w[ep-1]).each do |t|
        t.tournament_monitor&.destroy
        t.destroy
      end
      Player.where(id: [@player_a&.id, @player_b&.id].compact).delete_all
      User.where(email: "test-carambus-app-lifecycle@carambus.de").delete_all
    end

    # AC-4: ohne Auth -> 401
    test "tournament create ohne Auth gibt 401" do
      post_json("/api/external_tournament/tournament", {region: {shortname: "NBV"}, external_id: "ep-1"}, nil)
      assert_response :unauthorized
    end

    # AC-1: create + Idempotenz
    test "tournament create + idempotent" do
      post_json("/api/external_tournament/tournament",
        {region: {shortname: "NBV"}, external_id: "ep-1", title: "EP", location: {id: @location.id}}, login_jwt)
      assert_response :created
      body = JSON.parse(response.body)
      assert_equal "carambus.tournament/v1", body["schema"]
      tid = body.dig("tournament", "id")
      assert tid.present?
      assert body.dig("tournament", "tournament_monitor_id").present?

      post_json("/api/external_tournament/tournament",
        {region: {shortname: "NBV"}, external_id: "ep-1"}, login_jwt)
      assert_response :ok
      assert_equal tid, JSON.parse(response.body).dig("tournament", "id")
    end

    # AC-3: tables-Discovery zeigt Verfuegbarkeit (in_tournament, bindungsbasiert)
    test "tables discovery enthaelt in_tournament" do
      get "/api/external_tournament/tables",
        params: {location_id: @location.id, region: "NBV"}, headers: auth_headers(login_jwt)
      assert_response :success
      body = JSON.parse(response.body)
      assert body["tables"].present?, "Location hat Tische (Fixtures)"
      assert(body["tables"].all? { |t| t.key?("in_tournament") })
    end

    # AC-2: lock_table-Controller-Response (Lock = Bindung; Response in_tournament, kein Crash)
    test "lock_table bindet Tisch + Response in_tournament" do
      jwt = login_jwt
      post_json("/api/external_tournament/tournament",
        {region: {shortname: "NBV"}, external_id: "ep-1", title: "EP", location: {id: @location.id}}, jwt)
      assert_response :created

      monitor = TableMonitor.create!(state: "ready", data: {})
      tables(:one).update_columns(table_monitor_id: monitor.id)

      post_json("/api/external_tournament/lock_table",
        {region: {shortname: "NBV"}, tournament: {external_id: "ep-1"}, table: {id: tables(:one).id}}, jwt)
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal true, body["in_tournament"]
      assert_equal monitor.id, body["table_monitor_id"]
    ensure
      tables(:one).update_columns(table_monitor_id: nil)
      TableMonitor.where(id: monitor.id).delete_all if defined?(monitor) && monitor
    end

    # AC-4: start_game ohne Auth -> 401
    test "start_game ohne Auth gibt 401" do
      post_json("/api/external_tournament/start_game",
        {region: {shortname: "NBV"}, external_id: "g1"}, nil)
      assert_response :unauthorized
    end

    # AC-1: start_game Happy-Path (per-Spieler-Disziplinen) -> Warmup, Response-Shape
    test "start_game erzeugt Spiel im Warmup" do
      jwt = login_jwt
      post_json("/api/external_tournament/tournament",
        {region: {shortname: "NBV"}, external_id: "ep-1", title: "EP", location: {id: @location.id}}, jwt)
      assert_response :created

      monitor = TableMonitor.create!(state: "ready", data: {})
      tables(:one).update_columns(table_monitor_id: monitor.id)
      post_json("/api/external_tournament/lock_table",
        {region: {shortname: "NBV"}, tournament: {external_id: "ep-1"}, table: {id: tables(:one).id}}, jwt)
      assert_response :success

      post_json("/api/external_tournament/start_game", {
        region: {shortname: "NBV"}, tournament: {external_id: "ep-1"}, table: {id: tables(:one).id},
        external_id: "g1", free_game_form: "karambol", innings_goal: 25, sets_to_play: 1, sets_to_win: 1,
        participants: [
          {role: "playera", player: {firstname: "Dick", lastname: "JASPERS"}, discipline: "3-Band", balls_goal: 30},
          {role: "playerb", player: {firstname: "Myung Woo", lastname: "CHO"}, discipline: "Freie Partie", balls_goal: 100}
        ]
      }, jwt)
      assert_response :created
      body = JSON.parse(response.body)
      assert body["game_id"].present?
      assert_includes %w[warmup warmup_a warmup_b match_shootout playing], body["state"]
    ensure
      tables(:one).update_columns(table_monitor_id: nil)
      TableMonitor.where(id: monitor.id).delete_all if defined?(monitor) && monitor
    end

    # === Plan 17-04: acknowledge_result (Result-Hold + Pull) ===

    # AC-3: ohne Auth -> 401
    test "acknowledge_result ohne Auth gibt 401" do
      post_json("/api/external_tournament/acknowledge_result",
        {region: {shortname: "NBV"}, tournament: {external_id: "ep-1"}, game: {external_id: "x"}}, nil)
      assert_response :unauthorized
    end

    # AC-2: Happy-Path -> 200 carambus.ack/v1 + Ergebnis + Release
    test "acknowledge_result liefert erfasstes Ergebnis + gibt frei (carambus.ack/v1)" do
      jwt = login_jwt
      monitor, game = setup_held_game(jwt, external_id: "ack-g1")

      post_json("/api/external_tournament/acknowledge_result",
        {region: {shortname: "NBV"}, tournament: {external_id: "ep-1"}, game: {external_id: "ack-g1"}}, jwt)
      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal "carambus.ack/v1", body["schema"]
      assert_equal 100, body.dig("result", "Ergebnis1")
      assert_equal 60, body.dig("result", "Ergebnis2")
      assert_equal false, body["already_acknowledged"]
      assert body["acknowledged_at"].present?
      assert_equal "ready_for_new_match", body["state"], "Hold verlassen (Tisch frei)"
      assert game.reload.result_acknowledged_at.present?
    ensure
      tables(:one).update_columns(table_monitor_id: nil)
      TableMonitor.where(id: monitor.id).delete_all if defined?(monitor) && monitor
    end

    # AC-3: Spiel noch nicht am Hold -> 409 mit aktuellem state
    test "acknowledge_result auf nicht-bereitem Spiel gibt 409" do
      jwt = login_jwt
      monitor, _game = setup_held_game(jwt, external_id: "ack-g2", state: "playing")

      post_json("/api/external_tournament/acknowledge_result",
        {region: {shortname: "NBV"}, tournament: {external_id: "ep-1"}, game: {external_id: "ack-g2"}}, jwt)
      assert_response :conflict
      assert_equal "playing", JSON.parse(response.body)["state"]
    ensure
      tables(:one).update_columns(table_monitor_id: nil)
      TableMonitor.where(id: monitor.id).delete_all if defined?(monitor) && monitor
    end

    # === Plan 17-05: end_tournament (Lifecycle-Exit) ===

    test "end_tournament ohne Auth gibt 401" do
      post_json("/api/external_tournament/end_tournament",
        {region: {shortname: "NBV"}, tournament: {external_id: "ep-1"}}, nil)
      assert_response :unauthorized
    end

    test "end_tournament gibt Tische frei + schließt Turnier (carambus.tournament_end/v1)" do
      jwt = login_jwt
      monitor, _game = setup_held_game(jwt, external_id: "end-g1")

      post_json("/api/external_tournament/end_tournament",
        {region: {shortname: "NBV"}, tournament: {external_id: "ep-1"}}, jwt)
      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal "carambus.tournament_end/v1", body["schema"]
      assert body["released_tables"] >= 1, "mind. ein Tisch freigegeben"
      assert_equal "closed", body["tournament_monitor_state"]
      assert_nil monitor.reload.tournament_monitor_id, "Tisch ungebunden"

      post_json("/api/external_tournament/end_tournament",
        {region: {shortname: "NBV"}, tournament: {external_id: "ep-1"}}, jwt)
      assert_response :ok
      assert_equal 0, JSON.parse(response.body)["released_tables"], "idempotent"
    ensure
      tables(:one).update_columns(table_monitor_id: nil)
      TableMonitor.where(id: monitor.id).delete_all if defined?(monitor) && monitor
    end

    # === Plan 16-01: end_tournament cleanup-Flag (Teardown) ===

    test "end_tournament mit cleanup:true loescht Turnier + Marker-Games (AC-3)" do
      jwt = login_jwt
      monitor, game = setup_held_game(jwt, external_id: "tdwn-g1")
      # Marker setzen (setup_held_game stempelt ihn nicht) → cleanup enumeriert hierueber.
      game.update!(data: game.data.merge("tournament_external_id" => "ep-1"))

      post_json("/api/external_tournament/end_tournament",
        {region: {shortname: "NBV"}, tournament: {external_id: "ep-1"}, cleanup: true}, jwt)
      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal "carambus.tournament_end/v1", body["schema"]
      assert_equal true, body["tournament_deleted"]
      assert body["games_deleted"] >= 1, "mind. ein Marker-Game geloescht"
      refute Game.exists?(game.id), "Marker-Game geloescht"
      refute Tournament.where(region_id: @nbv.id, external_id: "ep-1").exists?, "Turnier geloescht"
    ensure
      tables(:one).update_columns(table_monitor_id: nil)
      TableMonitor.where(id: monitor.id).delete_all if defined?(monitor) && monitor
    end

    test "end_tournament ohne cleanup-Flag laesst Turnier + Games bestehen (AC-3 Default-off)" do
      jwt = login_jwt
      monitor, game = setup_held_game(jwt, external_id: "tdwn-g2")
      game.update!(data: game.data.merge("tournament_external_id" => "ep-1"))

      post_json("/api/external_tournament/end_tournament",
        {region: {shortname: "NBV"}, tournament: {external_id: "ep-1"}}, jwt)
      assert_response :ok
      body = JSON.parse(response.body)
      assert_nil body["tournament_deleted"], "kein Teardown ohne Flag"
      assert_nil body["games_deleted"]
      assert Game.exists?(game.id), "Marker-Game bleibt (Default off)"
      assert Tournament.where(region_id: @nbv.id, external_id: "ep-1").exists?, "Turnier bleibt (Default off)"
    ensure
      if defined?(game) && game
        GameParticipation.where(game_id: game.id).delete_all
        Game.where(id: game.id).delete_all
      end
      tables(:one).update_columns(table_monitor_id: nil)
      TableMonitor.where(id: monitor.id).delete_all if defined?(monitor) && monitor
    end

    # === Plan 17-06: player_reconcile ===

    test "player_reconcile ohne Auth gibt 401" do
      post_json("/api/external_tournament/player_reconcile",
        {region: {shortname: "NBV"}, participants: [{ref: "a", dbu_nr: 43001}]}, nil)
      assert_response :unauthorized
    end

    test "player_reconcile ohne participants gibt 422" do
      post_json("/api/external_tournament/player_reconcile",
        {region: {shortname: "NBV"}, participants: []}, login_jwt)
      assert_response :unprocessable_entity
    end

    test "player_reconcile liefert dbu_nr (matched) + matched:false (unmatched)" do
      post_json("/api/external_tournament/player_reconcile", {
        region: {shortname: "NBV"},
        participants: [
          {ref: "p1", dbu_nr: 43001},
          {ref: "p2", firstname: "Niemand", lastname: "Geist"}
        ]
      }, login_jwt)
      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal "carambus.player_reconcile/v1", body["schema"]
      assert_equal "NBV", body.dig("region", "shortname")
      assert_equal 2, body["results"].size

      matched = body["results"].find { |r| r["ref"] == "p1" }
      assert_equal true, matched["matched"]
      assert_equal "43001", matched.dig("player", "dbu_nr")
      assert_equal @player_a.id, matched.dig("player", "id")

      unmatched = body["results"].find { |r| r["ref"] == "p2" }
      assert_equal false, unmatched["matched"]
      assert_nil unmatched["player"]
    end

    private

    ACK_BA = {
      "Spieler1" => 43001, "Spieler2" => 43002, "Sets1" => 1, "Sets2" => 0,
      "Ergebnis1" => 100, "Ergebnis2" => 60, "Aufnahmen1" => 5, "Aufnahmen2" => 5,
      "Höchstserie1" => 50, "Höchstserie2" => 30, "Tischnummer" => 1
    }.freeze

    # Baut ein App-Turnier (ep-1) + gebundenen Tisch + ein Game im angegebenen State
    # mit erfasstem ba_results (Hold-Simulation). Liefert [monitor, game].
    def setup_held_game(jwt, external_id:, state: "final_match_score")
      post_json("/api/external_tournament/tournament",
        {region: {shortname: "NBV"}, external_id: "ep-1", title: "EP", location: {id: @location.id}}, jwt)
      monitor = TableMonitor.create!(state: "ready", data: {})
      tables(:one).update_columns(table_monitor_id: monitor.id)
      post_json("/api/external_tournament/lock_table",
        {region: {shortname: "NBV"}, tournament: {external_id: "ep-1"}, table: {id: tables(:one).id}}, jwt)
      monitor.reload

      game = Game.create!(group_no: 1, seqno: 1, table_no: 1,
        data: {"external_id" => external_id, "ba_results" => ACK_BA, "tmp_results" => {"sets" => [ACK_BA]}})
      GameParticipation.create!(game: game, player: @player_a, role: "playera")
      GameParticipation.create!(game: game, player: @player_b, role: "playerb")
      monitor.update!(game_id: game.id, data: {"ba_results" => ACK_BA, "sets" => [ACK_BA]})
      monitor.update_columns(state: state)
      monitor.reload
      [monitor, game]
    end

    def auth_headers(jwt)
      h = {"Content-Type" => "application/json", "Accept" => "application/json"}
      h["Authorization"] = "Bearer #{jwt}" if jwt
      h
    end

    def post_json(path, payload, jwt)
      post path, params: payload.to_json, headers: auth_headers(jwt)
    end

    def login_jwt
      post "/login",
        params: {user: {email: @service_user.email, password: "password123"}}.to_json,
        headers: {"Content-Type" => "application/json", "Accept" => "application/json"}
      raise "Login failed in test: #{response.code} #{response.body}" unless response.successful?
      jwt = response.headers["Authorization"].to_s.sub(/\ABearer\s+/, "")
      cookies.delete(:_carambus_session) if cookies.respond_to?(:delete)
      reset!
      jwt
    end
  end
end
