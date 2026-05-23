# frozen_string_literal: true

require "test_helper"

# Plan 20-01 (v0.6 F3): Controller-Tests fuer den Disziplin-Discovery-Endpoint
#   GET /api/external_tournament/disciplines -> carambus.disciplines/v1
# Auth-Muster (Service-User + JWT) wie die uebrigen external_tournament-Tests.
module Api
  class ExternalTournamentsDisciplinesTest < ActionDispatch::IntegrationTest
    setup do
      @nbv = regions(:nbv)
      @service_user = User.create!(email: "test-2band-disc@carambus.de", password: "password123")
      @season = Season.create!(name: "DISC-CTRL-2099/2100")

      @table_kind = TableKind.create!(name: "DISC Small Billard")
      @super = Discipline.create!(name: "DISC-Dreiband")
      @discipline = Discipline.create!(name: "DISC-Dreiband klein", synonyms: "DISC-3B klein",
        table_kind: @table_kind, super_discipline: @super)
      PlayerClass.create!(discipline: @discipline, shortname: "2")
      PlayerClass.create!(discipline: @discipline, shortname: "1")
      @plan = TournamentPlan.create!(name: "DISC-Default8", players: 8, tables: 2, ngroups: 1, nrepeats: 1,
        rulesystem: "DISC-RS", executor_class: "DISC::Exec", executor_params: "k: v",
        more_description: "mehr", even_more_description: "noch mehr")
      DisciplineTournamentPlan.create!(discipline: @discipline, tournament_plan: @plan,
        players: 8, player_class: "1", points: 40, innings: 20)
      DisciplineTournamentPlan.create!(discipline: @discipline, tournament_plan: @plan,
        players: 8, player_class: "2", points: 30, innings: 20)

      @player = Player.create!(firstname: "DiscCtrl", lastname: "Tester",
        region_id: @nbv.id, cc_id: 199_201, dbu_nr: 99_201)
      PlayerRanking.create!(region: @nbv, season: @season, discipline: @discipline,
        player: @player, rank: 1, gd: 1.0)

      # Disziplin ohne Region-Bezug -> darf nicht erscheinen.
      @irrelevant = Discipline.create!(name: "DISC-Snooker irrelevant")
    end

    teardown do
      DisciplineTournamentPlan.where(discipline_id: [@discipline&.id, @irrelevant&.id].compact).delete_all
      PlayerRanking.where(season_id: @season&.id).delete_all
      Player.where(id: @player&.id).delete_all
      PlayerClass.where(discipline_id: @discipline&.id).delete_all
      @plan&.destroy
      [@discipline, @irrelevant, @super].compact.each(&:destroy)
      @table_kind&.destroy
      @season&.destroy
      User.where(email: "test-2band-disc@carambus.de").delete_all
    end

    test "disciplines returns region-relevant disciplines with schema (AC-1)" do
      jwt = login_jwt
      get "/api/external_tournament/disciplines?region=NBV", headers: auth_headers(jwt)
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "carambus.disciplines/v1", body["schema"]
      assert_equal "NBV", body.dig("region", "shortname")

      names = body["disciplines"].map { |d| d["name"] }
      assert_includes names, "DISC-Dreiband klein"
      refute_includes names, "DISC-Snooker irrelevant", "Disziplin ohne Region-Bezug fehlt"

      disc = body["disciplines"].find { |d| d["name"] == "DISC-Dreiband klein" }
      assert_equal "DISC Small Billard", disc["table_kind"]
      assert_equal "DISC-Dreiband", disc["super_discipline"]
      assert_equal %w[2 1], disc["player_classes"], "nach PLAYER_CLASS_ORDER (worst->best)"
      refute_includes disc["synonyms"], "DISC-Dreiband klein"
    end

    test "disciplines exposes normalized tournament_plans matrix incl. executor (AC-2)" do
      jwt = login_jwt
      get "/api/external_tournament/disciplines?region=NBV", headers: auth_headers(jwt)
      assert_response :success
      body = JSON.parse(response.body)

      disc = body["disciplines"].find { |d| d["name"] == "DISC-Dreiband klein" }
      assert_equal 2, disc["parameters"].size
      row = disc["parameters"].first
      assert_equal "DISC-Default8", row["tournament_plan"]
      assert_equal 40, row["points"]
      assert_equal "1", row["player_class"]

      # Referenz-Integritaet + volle Plan-Felder inkl. Executor (D-20-01-E).
      assert_includes body["tournament_plans"].keys, "DISC-Default8"
      plan = body["tournament_plans"]["DISC-Default8"]
      assert_equal 8, plan["players"]
      assert_equal 2, plan["tables"]
      assert_equal "DISC::Exec", plan["executor_class"]
      assert_equal "k: v", plan["executor_params"]
      assert_equal "noch mehr", plan["even_more_description"]
      disc["parameters"].each { |p| assert_includes body["tournament_plans"].keys, p["tournament_plan"] }
    end

    test "disciplines with unknown region returns 404 (AC-3)" do
      jwt = login_jwt
      get "/api/external_tournament/disciplines?region=ZZZ", headers: auth_headers(jwt)
      assert_response :not_found
    end

    test "disciplines without auth returns 401 (AC-3)" do
      get "/api/external_tournament/disciplines?region=NBV", headers: auth_headers(nil)
      assert_response :unauthorized
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
