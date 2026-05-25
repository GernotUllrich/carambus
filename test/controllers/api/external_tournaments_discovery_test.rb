# frozen_string_literal: true

require "test_helper"

# Plan 18-01: Controller-Tests fuer die Discovery-Read-Endpoints
#   GET /api/external_tournament/clubs         -> carambus.clubs/v1
#   GET /api/external_tournament/club_players  -> carambus.club_players/v1
# Auth-Muster (Service-User + JWT) wie die uebrigen external_tournament-Tests.
module Api
  class ExternalTournamentsDiscoveryTest < ActionDispatch::IntegrationTest
    setup do
      @nbv = regions(:nbv)
      @service_user = User.create!(email: "test-2band-discovery@carambus.de", password: "password123")
      @season = Season.create!(name: "ROSTER-CTRL-2099/2100")
      @club = Club.create!(region: @nbv, cc_id: 180_201, shortname: "TST-DC", name: "Discovery Test Club")
      @club2 = Club.create!(region: @nbv, cc_id: 180_202, shortname: "TST-DC2", name: "Discovery Test Club 2")

      @active = mk_player("Active", 180_211, 95_001)
      @guest = mk_player("Guest", 180_212, 95_002)
      participate(@active, @club, "active")
      participate(@guest, @club, "guest")
      participate(mk_player("Active2", 180_221, 95_003), @club2, "active")

      # Plan 20-03 (F5): Disziplin + Leistungsklassen; @active in Landesliga.
      @disc = Discipline.create!(name: "ROSTER-CTRL-Dreiband")
      @pc_ll = PlayerClass.create!(discipline: @disc, shortname: "Landesliga")
      @pc_bl = PlayerClass.create!(discipline: @disc, shortname: "Bezirksliga")
      PlayerRanking.create!(region_id: @nbv.id, season_id: @season.id, discipline_id: @disc.id,
        player_id: @active.id, player_class_id: @pc_ll.id, rank: 1)
    end

    teardown do
      PlayerRanking.where(discipline_id: @disc&.id).delete_all
      SeasonParticipation.where(season_id: @season&.id).delete_all
      Player.where("firstname LIKE ?", "Test18-01D-%").delete_all
      PlayerClass.where(discipline_id: @disc&.id).delete_all
      @disc&.destroy
      Club.where(cc_id: [180_201, 180_202]).delete_all
      @season&.destroy
      User.where(email: "test-2band-discovery@carambus.de").delete_all
    end

    test "clubs returns carambus.clubs/v1 with the region's cc_id clubs" do
      jwt = login_jwt
      get "/api/external_tournament/clubs?region=NBV", headers: auth_headers(jwt)
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "carambus.clubs/v1", body["schema"]
      assert_equal "NBV", body.dig("region", "shortname")
      ccids = body["clubs"].map { |c| c["cc_id"] }
      assert_includes ccids, 180_201
      assert_includes ccids, 180_202
    end

    test "club_players (single) returns only active players with cc_id+dbu_nr+status" do
      jwt = login_jwt
      Season.stub(:current_season, @season) do
        get "/api/external_tournament/club_players?region=NBV&club_cc_id=180201", headers: auth_headers(jwt)
      end
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "carambus.club_players/v1", body["schema"]
      assert_equal 180_201, body.dig("club", "cc_id")
      players = body["players"]
      assert_equal [180_211], players.map { |p| p["cc_id"] }, "only active player (guest excluded)"
      assert_equal "95001", players.first["dbu_nr"]
      assert_equal "active", players.first["status"]
    end

    test "club_players (club_cc_ids) returns clubs array variant" do
      jwt = login_jwt
      Season.stub(:current_season, @season) do
        get "/api/external_tournament/club_players?region=NBV&club_cc_ids=180201,180202", headers: auth_headers(jwt)
      end
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "carambus.club_players/v1", body["schema"]
      assert_nil body["club"], "multi variant uses clubs:[] not club:{}"
      returned = body["clubs"].map { |entry| entry.dig("club", "cc_id") }
      assert_equal [180_201, 180_202].sort, returned.sort
    end

    test "club_players without club_cc_id returns 422" do
      jwt = login_jwt
      get "/api/external_tournament/club_players?region=NBV", headers: auth_headers(jwt)
      assert_response :unprocessable_entity
    end

    test "club_players with unknown club_cc_id returns 404 (region-scoped)" do
      jwt = login_jwt
      get "/api/external_tournament/club_players?region=NBV&club_cc_id=99999999", headers: auth_headers(jwt)
      assert_response :not_found
    end

    test "clubs with unknown region returns 404" do
      jwt = login_jwt
      get "/api/external_tournament/clubs?region=ZZZ", headers: auth_headers(jwt)
      assert_response :not_found
    end

    test "clubs without auth returns 401" do
      get "/api/external_tournament/clubs?region=NBV", headers: auth_headers(nil)
      assert_response :unauthorized
    end

    # Plan 20-03 (F5)
    test "club_players with discipline+player_class filters to matching players + field (AC-1)" do
      bl = mk_player("BL", 180_231, 95_010)
      participate(bl, @club, "active")
      PlayerRanking.create!(region_id: @nbv.id, season_id: @season.id, discipline_id: @disc.id,
        player_id: bl.id, player_class_id: @pc_bl.id, rank: 1)
      jwt = login_jwt
      Season.stub(:current_season, @season) do
        get "/api/external_tournament/club_players?region=NBV&club_cc_id=180201&discipline=ROSTER-CTRL-Dreiband&player_class=Landesliga",
          headers: auth_headers(jwt)
      end
      assert_response :success
      body = JSON.parse(response.body)
      players = body["players"]
      assert_equal [180_211], players.map { |p| p["cc_id"] }, "only Landesliga players"
      assert_equal "Landesliga", players.first["player_class"]
    end

    test "club_players with discipline (no filter) adds player_class field to all active players (AC-2)" do
      jwt = login_jwt
      Season.stub(:current_season, @season) do
        get "/api/external_tournament/club_players?region=NBV&club_cc_id=180201&discipline=ROSTER-CTRL-Dreiband",
          headers: auth_headers(jwt)
      end
      assert_response :success
      body = JSON.parse(response.body)
      active = body["players"].find { |p| p["cc_id"] == 180_211 }
      assert active.key?("player_class"), "player_class field present with discipline"
      assert_equal "Landesliga", active["player_class"]
    end

    test "club_players with player_class but without discipline returns 422 (AC-3)" do
      jwt = login_jwt
      get "/api/external_tournament/club_players?region=NBV&club_cc_id=180201&player_class=Landesliga",
        headers: auth_headers(jwt)
      assert_response :unprocessable_entity
    end

    test "club_players with unresolvable discipline returns 404 (AC-3)" do
      jwt = login_jwt
      get "/api/external_tournament/club_players?region=NBV&club_cc_id=180201&discipline=Quatsch-gibt-es-nicht",
        headers: auth_headers(jwt)
      assert_response :not_found
    end

    test "club_players without discipline keeps unchanged response (no player_class key) (AC-2 behavior-preserving)" do
      jwt = login_jwt
      Season.stub(:current_season, @season) do
        get "/api/external_tournament/club_players?region=NBV&club_cc_id=180201", headers: auth_headers(jwt)
      end
      assert_response :success
      body = JSON.parse(response.body)
      refute body["players"].first.key?("player_class"), "no discipline -> no player_class key"
    end

    private

    def mk_player(suffix, cc_id, dbu_nr)
      Player.create!(firstname: "Test18-01D-#{suffix}", lastname: "Disc#{suffix}",
        region_id: @nbv.id, cc_id: cc_id, dbu_nr: dbu_nr)
    end

    def participate(player, club, status)
      SeasonParticipation.create!(season: @season, club: club, player: player, status: status)
    end

    def auth_headers(jwt)
      h = {"Content-Type" => "application/json", "Accept" => "application/json"}
      h["Authorization"] = "Bearer #{jwt}" if jwt
      h
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
