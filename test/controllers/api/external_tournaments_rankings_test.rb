# frozen_string_literal: true

require "test_helper"

# Plan 19-01: Controller-Tests fuer den Ranking-Setzlisten-Endpoint
#   GET /api/external_tournament/player_rankings -> carambus.player_rankings/v1
# Auth-Muster (Service-User + JWT) wie die uebrigen external_tournament-Tests.
module Api
  class ExternalTournamentsRankingsTest < ActionDispatch::IntegrationTest
    setup do
      @nbv = regions(:nbv)
      @service_user = User.create!(email: "test-carambus-app-ranking@carambus.de", password: "password123")
      @season = Season.create!(name: "RANK-CTRL-2099/2100")
      @discipline = Discipline.create!(name: "Test19 Dreiband klein")

      @p1 = mk_player("One", 190_201, 96_001)   # Rang 1
      @p2 = mk_player("Two", 190_202, 96_002)   # Rang 2
      @p3 = mk_player("Three", 190_203, 96_003) # Rang 3
      @p_norank = mk_player("Nor", 190_204, 96_004) # kein Ranking

      mk_rank(@p2, rank: 2, gd: 1.500)
      mk_rank(@p1, rank: 1, gd: 2.250)
      mk_rank(@p3, rank: 3, gd: 0.900)
    end

    teardown do
      PlayerRanking.where(season_id: @season&.id).delete_all
      Player.where("firstname LIKE ?", "Test19R-%").delete_all
      @discipline&.destroy
      @season&.destroy
      User.where(email: "test-carambus-app-ranking@carambus.de").delete_all
    end

    test "player_rankings returns players sorted by rank with schema" do
      jwt = login_jwt
      # season explizit pinnen: Default ist die VORSAISON (D-19-01-SEASON), die Test-Saison ist eine
      # synthetische ("RANK-CTRL-…") — daher die Rankings dieser Saison gezielt anfragen.
      get "/api/external_tournament/player_rankings?region=NBV&discipline=#{CGI.escape(@discipline.name)}&season=#{CGI.escape(@season.name)}",
        headers: auth_headers(jwt)
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "carambus.player_rankings/v1", body["schema"]
      assert_equal "NBV", body.dig("region", "shortname")
      assert_equal @discipline.name, body.dig("discipline", "name")
      ccids = body["players"].map { |p| p["cc_id"] }
      assert_equal [190_201, 190_202, 190_203], ccids, "nach Rang sortiert (1,2,3)"
      assert_equal 1, body["players"].first["rank"]
      assert_equal "96001", body["players"].first["dbu_nr"]
      assert_in_delta 2.250, body["players"].first["gd"], 0.001
    end

    test "player_rankings filters by player_cc_ids and reports unranked" do
      jwt = login_jwt
      get "/api/external_tournament/player_rankings?region=NBV&discipline=#{CGI.escape(@discipline.name)}" \
          "&season=#{CGI.escape(@season.name)}&player_cc_ids=190203,190201,190204",
        headers: auth_headers(jwt)
      assert_response :success
      body = JSON.parse(response.body)
      ccids = body["players"].map { |p| p["cc_id"] }
      assert_equal [190_201, 190_203], ccids, "nur angeforderte, nach Rang sortiert"
      assert_equal ["190204"], body["unranked"], "ohne Ranking → unranked"
    end

    test "player_rankings resolves discipline via synonym" do
      @discipline.update!(synonyms: "Dreiband-Synonym19")
      jwt = login_jwt
      get "/api/external_tournament/player_rankings?region=NBV&discipline=Dreiband-Synonym19",
        headers: auth_headers(jwt)
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal @discipline.name, body.dig("discipline", "name")
    end

    test "player_rankings without discipline returns 422" do
      jwt = login_jwt
      get "/api/external_tournament/player_rankings?region=NBV", headers: auth_headers(jwt)
      assert_response :unprocessable_entity
    end

    test "player_rankings with unknown discipline returns 404" do
      jwt = login_jwt
      get "/api/external_tournament/player_rankings?region=NBV&discipline=GibtsNicht19",
        headers: auth_headers(jwt)
      assert_response :not_found
    end

    test "player_rankings with unknown region returns 404" do
      jwt = login_jwt
      get "/api/external_tournament/player_rankings?region=ZZZ&discipline=#{CGI.escape(@discipline.name)}",
        headers: auth_headers(jwt)
      assert_response :not_found
    end

    test "player_rankings without auth returns 401" do
      get "/api/external_tournament/player_rankings?region=NBV&discipline=x", headers: auth_headers(nil)
      assert_response :unauthorized
    end

    private

    def mk_player(suffix, cc_id, dbu_nr)
      Player.create!(firstname: "Test19R-#{suffix}", lastname: "Rank#{suffix}",
        region_id: @nbv.id, cc_id: cc_id, dbu_nr: dbu_nr)
    end

    def mk_rank(player, rank:, gd:)
      PlayerRanking.create!(player: player, region: @nbv, season: @season,
        discipline: @discipline, rank: rank, gd: gd)
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
