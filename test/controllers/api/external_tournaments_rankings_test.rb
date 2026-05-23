# frozen_string_literal: true

require "test_helper"

# Plan 19-01 (v0.6 F1): Controller-Tests fuer GET /api/external_tournament/player_rankings.
# Saison wird via &season=<name> gepinnt (Default = Vorsaison ist im RankingQuery-Service getestet).
module Api
  class ExternalTournamentsRankingsTest < ActionDispatch::IntegrationTest
    setup do
      @nbv = regions(:nbv)
      @service_user = User.create!(email: "test-2band-rankings@carambus.de", password: "password123")
      @discipline = Discipline.create!(name: "RankCtrl-Dreiband", synonyms: "RC-3B")
      @season = Season.create!(name: "RANKCTRL-2099/2100")
      @p1 = mk_player("RC1", 197_001, 97_001)
      @p2 = mk_player("RC2", 197_002, 97_002)
      rank!(@p1, rank: 2, gd: 1.0)
      rank!(@p2, rank: 1, gd: 5.0)
    end

    teardown do
      PlayerRanking.where(discipline_id: @discipline&.id).delete_all
      Player.where(id: [@p1, @p2].compact.map(&:id)).delete_all
      Season.where(name: "RANKCTRL-2099/2100").delete_all
      @discipline&.destroy
      User.where(email: "test-2band-rankings@carambus.de").delete_all
    end

    test "player_rankings liefert nach Rang sortierte Setzliste (carambus.player_rankings/v1)" do
      get rankings_url(discipline: "RankCtrl-Dreiband", season: @season.name), headers: auth_headers(login_jwt)
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "carambus.player_rankings/v1", body["schema"]
      assert_equal "NBV", body.dig("region", "shortname")
      assert_equal "RankCtrl-Dreiband", body.dig("discipline", "name")
      assert_equal [197_002, 197_001], body["players"].map { |p| p["cc_id"] }
      assert_equal 1, body["players"].first["rank"]
      assert_equal "97002", body["players"].first["dbu_nr"]
    end

    test "player_cc_ids-Filter + unranked" do
      get rankings_url(discipline: "RankCtrl-Dreiband", season: @season.name, player_cc_ids: "197001,199999"),
        headers: auth_headers(login_jwt)
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal [197_001], body["players"].map { |p| p["cc_id"] }
      assert_equal ["199999"], body["unranked"]
    end

    test "ohne discipline -> 422" do
      get rankings_url(region: "NBV"), headers: auth_headers(login_jwt)
      assert_response :unprocessable_entity
    end

    test "unbekannte Disziplin -> 404" do
      get rankings_url(discipline: "Gibt-Es-Nicht-XYZ"), headers: auth_headers(login_jwt)
      assert_response :not_found
    end

    test "unbekannte Region -> 404" do
      get "/api/external_tournament/player_rankings?region=ZZZ&discipline=RankCtrl-Dreiband",
        headers: auth_headers(login_jwt)
      assert_response :not_found
    end

    test "ohne Auth -> 401" do
      get rankings_url(discipline: "RankCtrl-Dreiband"), headers: auth_headers(nil)
      assert_response :unauthorized
    end

    private

    def rankings_url(region: "NBV", discipline: nil, season: nil, player_cc_ids: nil)
      q = {region: region, discipline: discipline, season: season, player_cc_ids: player_cc_ids}.compact
      "/api/external_tournament/player_rankings?" + q.map { |k, v| "#{k}=#{ERB::Util.url_encode(v.to_s)}" }.join("&")
    end

    def mk_player(suffix, cc_id, dbu_nr)
      Player.create!(firstname: "RC-#{suffix}", lastname: "Test#{suffix}",
        region_id: @nbv.id, cc_id: cc_id, dbu_nr: dbu_nr)
    end

    def rank!(player, rank:, gd:)
      PlayerRanking.create!(region_id: @nbv.id, season_id: @season.id, discipline_id: @discipline.id,
        player_id: player.id, rank: rank, gd: gd, hs: 5, balls: 100, innings: 30)
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
