# frozen_string_literal: true

require "test_helper"

# Plan 20-02 (v0.6 F4): Controller-Tests fuer den Categories-Discovery-Endpoint
#   GET /api/external_tournament/categories -> carambus.categories/v1
# Auth-Muster (Service-User + JWT) wie die uebrigen external_tournament-Tests.
module Api
  class ExternalTournamentsCategoriesTest < ActionDispatch::IntegrationTest
    setup do
      @nbv = regions(:nbv)
      @service_user = User.create!(email: "test-2band-cat@carambus.de", password: "password123")
      @region_cc = RegionCc.create!(region: @nbv, context: "nbv", cc_id: 70_101, shortname: "NBV",
        name: "CAT-CTRL RegionCc")

      @discipline = Discipline.create!(name: "CAT-Dreiband klein", synonyms: "CAT-3B klein")
      PlayerClass.create!(discipline: @discipline, shortname: "2")
      PlayerClass.create!(discipline: @discipline, shortname: "1")
      @branch = BranchCc.create!(discipline: @discipline, region_cc: @region_cc, context: "nbv",
        cc_id: 71_101, name: "CAT-Sparte-A")
      CategoryCc.create!(branch_cc: @branch, context: "nbv", cc_id: 72_101, name: "CAT-Damen",
        sex: "F", min_age: 0, max_age: 99, status: "Freigegeben")
      CategoryCc.create!(branch_cc: @branch, context: "nbv", cc_id: 72_102, name: "CAT-Herren",
        sex: "M", min_age: 0, max_age: 99, status: "Freigegeben")
    end

    teardown do
      CategoryCc.where(cc_id: [72_101, 72_102]).delete_all
      BranchCc.where(cc_id: 71_101, context: "nbv").delete_all
      PlayerClass.where(discipline_id: @discipline&.id).delete_all
      @discipline&.destroy
      @region_cc&.destroy
      User.where(email: "test-2band-cat@carambus.de").delete_all
    end

    test "categories with discipline returns schema + lists (AC-1)" do
      jwt = login_jwt
      get "/api/external_tournament/categories?region=NBV&discipline=CAT-Dreiband+klein",
        headers: auth_headers(jwt)
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "carambus.categories/v1", body["schema"]
      assert_equal "NBV", body.dig("region", "shortname")
      assert body.key?("season")
      assert_equal %w[2 1], body["player_classes"], "nach PLAYER_CLASS_ORDER (worst->best)"
      assert_equal %w[CAT-Damen CAT-Herren], body["age_classes"]
      assert_equal %w[M F], body["genders"]
      cat = body["categories"].find { |c| c["name"] == "CAT-Herren" }
      assert_equal "M", cat["sex"]
      assert_equal "Freigegeben", cat["status"]
    end

    test "categories without discipline returns region-wide lists, player_classes empty (AC-2)" do
      jwt = login_jwt
      get "/api/external_tournament/categories?region=NBV", headers: auth_headers(jwt)
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal [], body["player_classes"]
      assert_includes body["age_classes"], "CAT-Damen"
    end

    test "categories without auth returns 401 (AC-3)" do
      get "/api/external_tournament/categories?region=NBV", headers: auth_headers(nil)
      assert_response :unauthorized
    end

    test "categories with unknown region returns 404 (AC-3)" do
      jwt = login_jwt
      get "/api/external_tournament/categories?region=ZZZ", headers: auth_headers(jwt)
      assert_response :not_found
    end

    test "categories with unresolvable discipline returns 404 (AC-3)" do
      jwt = login_jwt
      get "/api/external_tournament/categories?region=NBV&discipline=CAT-gibt-es-nicht",
        headers: auth_headers(jwt)
      assert_response :not_found
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
