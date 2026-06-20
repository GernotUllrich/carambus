# frozen_string_literal: true

require "test_helper"

# Plan 23-01 T3b: Controller-Tests fuer den Registration-Lists-Discovery-Endpoint
#   GET /api/external_tournament/registration_lists -> carambus.registration_lists/v1
# Datenquelle ist seit T3b TournamentCc statt RegistrationListCc (siehe
# RegistrationListQuery). Payload-Vertrag bleibt; status-Filter ist no-op;
# tournament_cc-Sub-Hash ist Self-Hash.
module Api
  class ExternalTournamentsRegistrationListsTest < ActionDispatch::IntegrationTest
    setup do
      @nbv = regions(:nbv)
      @service_user = User.create!(email: "test-carambus-app-rl@carambus.de", password: "password123")
      @region_cc = RegionCc.create!(region: @nbv, context: "nbv", cc_id: 70_201, shortname: "RL-NBV",
        name: "RL-CTRL RegionCc")

      @discipline = Discipline.create!(name: "RL-Dreiband klein", synonyms: "RL-3B-klein")
      @other_discipline = Discipline.create!(name: "RL-Pool")
      @branch = BranchCc.create!(discipline: @discipline, region_cc: @region_cc, context: "nbv",
        cc_id: 71_201, name: "RL-Sparte-A")
      @cat_herren = CategoryCc.create!(branch_cc: @branch, context: "nbv", cc_id: 72_201,
        name: "RL-Herren", sex: "M", min_age: 0, max_age: 99, status: "Freigegeben")

      @season = Season.create!(name: "RL-CTRL-2099/2100")

      @tcc_a = TournamentCc.create!(cc_id: 74_201, context: "nbv", name: "RL-CTRL NDM Herren",
        season: @season.name, discipline: @discipline, category_cc: @cat_herren,
        meldeliste_cc_id: 73_201,
        meldeliste_deadline: Date.new(2099, 6, 1),
        meldeliste_qualifying_date: Date.new(2099, 5, 1),
        tournament_start: Date.new(2099, 8, 1))
      @tcc_b = TournamentCc.create!(cc_id: 74_202, context: "nbv", name: "RL-CTRL NDM Open",
        season: @season.name, discipline: @discipline, category_cc: @cat_herren,
        meldeliste_cc_id: 73_202,
        meldeliste_deadline: Date.new(2099, 7, 1))
    end

    teardown do
      TournamentCc.where(cc_id: [74_201, 74_202]).delete_all
      CategoryCc.where(cc_id: [72_201]).delete_all
      BranchCc.where(cc_id: 71_201, context: "nbv").delete_all
      RegionCc.where(cc_id: 70_201).delete_all
      Season.where(name: ["RL-CTRL-2099/2100"]).delete_all
      [@discipline, @other_discipline].compact.each(&:destroy)
      User.where(email: "test-carambus-app-rl@carambus.de").delete_all
    end

    test "registration_lists happy path returns schema + items" do
      jwt = login_jwt
      get "/api/external_tournament/registration_lists?region=NBV&season=#{CGI.escape(@season.name)}",
        headers: auth_headers(jwt)
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "carambus.registration_lists/v1", body["schema"]
      assert_equal "NBV", body.dig("region", "shortname")
      assert_equal @season.name, body.dig("season", "name")
      assert_equal [73_201, 73_202], body["registration_lists"].map { |h| h["cc_id"] }
      first = body["registration_lists"].first
      assert_equal "RL-CTRL NDM Herren", first["name"]
      assert_nil first["status"], "T3b: status ist nil im Payload (kein Persist mehr)"
      assert_match(/\A2099-06-01/, first["deadline"].to_s)
      assert_equal "RL-Dreiband klein", first.dig("discipline", "name")
      assert_equal "RL-Herren", first.dig("category_cc", "name")
    end

    test "registration_lists without auth returns 401" do
      get "/api/external_tournament/registration_lists?region=NBV", headers: auth_headers(nil)
      assert_response :unauthorized
    end

    test "registration_lists with unknown region returns 404" do
      jwt = login_jwt
      get "/api/external_tournament/registration_lists?region=ZZZ", headers: auth_headers(jwt)
      assert_response :not_found
    end

    test "registration_lists with unresolvable season returns 404" do
      jwt = login_jwt
      get "/api/external_tournament/registration_lists?region=NBV&season=GibtsNicht-1900/1901",
        headers: auth_headers(jwt)
      assert_response :not_found
      body = JSON.parse(response.body)
      assert_match(/Season not found/, body["error"].to_s)
    end

    test "registration_lists with unresolvable discipline returns 404" do
      jwt = login_jwt
      get "/api/external_tournament/registration_lists?region=NBV&season=#{CGI.escape(@season.name)}&discipline=Fantasy",
        headers: auth_headers(jwt)
      assert_response :not_found
      body = JSON.parse(response.body)
      assert_match(/Discipline not found/, body["error"].to_s)
    end

    test "registration_lists status-param is no-op after T3b" do
      jwt = login_jwt
      get "/api/external_tournament/registration_lists?region=NBV&season=#{CGI.escape(@season.name)}&status=Freigegeben",
        headers: auth_headers(jwt)
      assert_response :success
      body = JSON.parse(response.body)
      # T3b: status-Filter wird ignoriert — beide Items kommen zurück.
      assert_equal [73_201, 73_202], body["registration_lists"].map { |h| h["cc_id"] }
    end

    test "registration_lists payload tournament_cc is self-hash (T3b)" do
      jwt = login_jwt
      get "/api/external_tournament/registration_lists?region=NBV&season=#{CGI.escape(@season.name)}",
        headers: auth_headers(jwt)
      body = JSON.parse(response.body)
      list_a = body["registration_lists"].find { |h| h["cc_id"] == 73_201 }
      list_b = body["registration_lists"].find { |h| h["cc_id"] == 73_202 }
      assert_equal @tcc_a.id, list_a.dig("tournament_cc", "id")
      assert_equal "RL-CTRL NDM Herren", list_a.dig("tournament_cc", "name")
      assert_match(/\A2099-08-01/, list_a.dig("tournament_cc", "date").to_s)

      # T3b: tournament_cc ist Self-Hash, immer present. tcc_b ohne tournament_start
      # liefert date: nil.
      assert_equal @tcc_b.id, list_b.dig("tournament_cc", "id")
      assert_nil list_b.dig("tournament_cc", "date")
    end

    private

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
