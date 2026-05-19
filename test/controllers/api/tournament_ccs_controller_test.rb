# frozen_string_literal: true

require "test_helper"

# Plan 14-G.14 Task 2: Specs für Api::TournamentCcsController#link_registration_list
#
# Auth-Pattern aus test/integration/jwt_login_route_test.rb übernommen:
# POST /login mit JSON-Credentials → Authorization-Header mit Bearer-JWT extrahieren.
module Api
  class TournamentCcsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @nbv = regions(:nbv)
      @bbv = regions(:bbv)
      @discipline = disciplines(:carom_3band)
      @season = seasons(:current)

      @service_user = User.create!(
        email: "test-syncer@carambus.de",
        password: "password123"
      )

      # RegistrationListCc benötigt branch_cc + category_cc — Inline-Setup-Kette:
      # region_cc → branch_cc → category_cc
      @region_cc = RegionCc.create!(cc_id: 999_801, context: "nbv", name: "NBV-CC", region: @nbv)
      @branch_cc = BranchCc.create!(cc_id: 999_802, context: "nbv", name: "Eurokegel", discipline: @discipline, region_cc: @region_cc)
      @category_cc = CategoryCc.create!(cc_id: 999_803, context: "nbv", name: "Open", branch_cc: @branch_cc)

      @tournament = Tournament.create!(
        title: "Test 3-Band Mannschaft",
        region_id: @nbv.id,
        season: @season,
        organizer: clubs(:bcw)
      )

      @tournament_cc = TournamentCc.create!(
        cc_id: 999_111,
        context: @nbv.shortname.downcase,
        name: @tournament.title,
        tournament: @tournament
      )

      @valid_body = {
        registration_list_link: {
          meldeliste_cc_id: 999_001,
          registration_list_name: "Test Meldeliste",
          region_shortname: "NBV",
          branch_cc_id: @branch_cc.id,
          season: @season.name,
          discipline_id: @discipline.id,
          category_cc_id: @category_cc.id
        }
      }
    end

    teardown do
      RegistrationListCc.where(cc_id: [999_001, 999_002]).delete_all
      TournamentCc.where(cc_id: 999_111).delete_all
      Tournament.where(title: "Test 3-Band Mannschaft").delete_all
      CategoryCc.where(cc_id: 999_803).delete_all
      BranchCc.where(cc_id: 999_802).delete_all
      RegionCc.where(cc_id: 999_801).delete_all
      User.where(email: "test-syncer@carambus.de").delete_all
    end

    test "link_registration_list with valid JWT + payload returns 200 with linked records" do
      patch_link(@valid_body, jwt: login_jwt)

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal @tournament_cc.id, body.dig("tournament_cc", "id")
      assert_equal 999_001, body.dig("registration_list_cc", "cc_id")
      assert_equal "nbv", body.dig("registration_list_cc", "context")
      assert body["version_id"].present?

      @tournament_cc.reload
      assert_not_nil @tournament_cc.registration_list_cc_id
      assert_equal body.dig("registration_list_cc", "id"), @tournament_cc.registration_list_cc_id
    end

    test "link_registration_list without Authorization header returns 401" do
      patch_link(@valid_body, jwt: nil)
      assert_response :unauthorized
    end

    test "link_registration_list with invalid JWT returns 401" do
      patch_link(@valid_body, jwt: "totally-invalid-token-string")
      assert_response :unauthorized
    end

    test "link_registration_list with region_shortname mismatch returns 422" do
      body = @valid_body.deep_dup
      body[:registration_list_link][:region_shortname] = "BBV"  # tournament is NBV
      patch_link(body, jwt: login_jwt)

      assert_response :unprocessable_entity
      assert_match(/Region mismatch/, response.body)
      @tournament_cc.reload
      assert_nil @tournament_cc.registration_list_cc_id, "Region-Mismatch darf KEIN DB-State-Change auslösen"
    end

    test "link_registration_list is idempotent (second identical call returns 200, no duplicate RegistrationListCc)" do
      jwt = login_jwt
      patch_link(@valid_body, jwt: jwt)
      assert_response :success
      first_id = JSON.parse(response.body).dig("registration_list_cc", "id")

      assert_no_difference -> { RegistrationListCc.where(cc_id: 999_001).count } do
        patch_link(@valid_body, jwt: jwt)
      end

      assert_response :success
      second_id = JSON.parse(response.body).dig("registration_list_cc", "id")
      assert_equal first_id, second_id, "Idempotent: zweiter Call darf KEIN neues RegistrationListCc anlegen"
    end

    test "link_registration_list with missing required params returns 400 or 422" do
      patch_link({}, jwt: login_jwt)
      # Strong-Params bei fehlendem :registration_list_link-Key → 400 Bad Request (ParameterMissing)
      assert_includes [400, 422], response.status, "Missing-Params soll 400 oder 422 sein, war: #{response.status}"
    end

    test "link_registration_list creates PaperTrail version for tournament_cc update" do
      versions_before = PaperTrail::Version.where(item_type: "TournamentCc", item_id: @tournament_cc.id).count

      patch_link(@valid_body, jwt: login_jwt)
      assert_response :success

      versions_after = PaperTrail::Version.where(item_type: "TournamentCc", item_id: @tournament_cc.id).count
      assert_operator versions_after, :>, versions_before, "PaperTrail-Version soll für TournamentCc-Update entstehen"
    end

    private

    def patch_link(body, jwt:)
      headers = {"Content-Type" => "application/json", "Accept" => "application/json"}
      headers["Authorization"] = "Bearer #{jwt}" if jwt
      patch "/api/tournament_ccs/#{@tournament_cc.id}/registration_list_link",
        params: body.to_json,
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
      # Session-Cookie nach Login löschen, damit subsequent Requests nur über Bearer-Header
      # authentifiziert werden (Session würde sonst nil-jwt-Tests verfälschen)
      cookies.delete(:_carambus_session) if cookies.respond_to?(:delete)
      reset!
      jwt
    end
  end
end
