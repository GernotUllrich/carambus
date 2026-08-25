# frozen_string_literal: true

require "test_helper"

# Plan 41-01: Controller-Tests fuer den Ergebnisarchiv-Endpoint
#   POST /api/external_tournament/tournament_result -> carambus.tournament_result/v1
# Auth-Muster (Service-User + JWT) wie die uebrigen external_tournament-Tests.
#
# `local_server?` wird gestubbt: der Endpoint laeuft ausschliesslich auf Location-Servern,
# und die Seeding-Validierung haengt daran (Seedings ohne aufgeloesten Spieler sind nur lokal
# erlaubt). Dieses Repo ist die Authority.
module Api
  class ExternalTournamentsTournamentResultTest < ActionDispatch::IntegrationTest
    setup do
      @nbv = regions(:nbv)
      @service_user = User.create!(email: "test-carambus-app-archive@carambus.de",
        password: "password123", confirmed_at: Time.zone.now)
      @tournament = tournaments(:local)
      @tournament.update_columns(region_id: @nbv.id)
      @player = players(:jaspers)
    end

    teardown do
      User.where(email: "test-carambus-app-archive@carambus.de").delete_all
    end

    def body_params
      {
        region: "NBV",
        tournament_id: @tournament.id,
        scheme: "plan",
        title: "Endstand",
        standings: [
          {player: {firstname: @player.firstname, lastname: @player.lastname},
           rank: 1, columns: {"Rang" => "1", "Name" => "#{@player.lastname}, #{@player.firstname}"}}
        ],
        games: [
          {gname: "R1.1", seqno: 1, round_no: 1, columns: {"Partie" => "1", "Ergebnis" => "15:11"}}
        ]
      }
    end

    def post_archive(params = nil)
      jwt = login_jwt
      ApplicationRecord.stub(:local_server?, true) do
        post "/api/external_tournament/tournament_result",
          params: params || body_params, headers: auth_headers(jwt), as: :json
      end
    end

    test "archiviert Endstand und Spiele und antwortet im Schema (AC-1/AC-3/AC-6)" do
      post_archive

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "carambus.tournament_result/v1", body["schema"]
      assert_equal "NBV", body.dig("region", "shortname")
      assert_equal @tournament.id, body.dig("tournament", "id")
      assert_equal 1, body["seedings_written"]
      assert_equal 1, body["games_written"]
      assert_empty body["players_unmatched"]
      assert body["archived"]
    end

    test "unbekanntes Turnier ergibt 404 (AC-6)" do
      post_archive(body_params.merge(tournament_id: 999_999_999))
      assert_response :not_found
    end

    # `resolve_external_tournament` filtert selbst auf region_id — ein Turnier fremder Region
    # kommt als nil an. Damit ist der Schutz Teil der Aufloesung, nicht ein eigener Zweig.
    test "Turnier einer fremden Region wird nicht beschrieben (AC-6)" do
      other = Region.where.not(id: @nbv.id).first
      skip "keine zweite Region in den Fixtures" if other.nil?
      @tournament.update_columns(region_id: other.id)

      post_archive
      assert_response :not_found
      assert_equal 0, @tournament.seedings.where("seedings.id >= ?", Seeding::MIN_ID).count
    end

    test "ohne gueltigen Token kein Schreibzugriff (AC-6)" do
      ApplicationRecord.stub(:local_server?, true) do
        post "/api/external_tournament/tournament_result", params: body_params, as: :json
      end
      refute_equal 200, response.status,
        "Der Endpoint darf ohne Auth nicht schreiben — gleiches Verhalten wie die Nachbar-Endpoints"
      assert_equal 0, @tournament.seedings.where("seedings.id >= ?", Seeding::MIN_ID).count
    end

    private

    # Muster der uebrigen external_tournament-Controller-Tests (dort ebenfalls je Datei
    # definiert) — bewusst uebernommen statt extrahiert, um den Nachbarn zu gleichen.
    def auth_headers(jwt)
      {"Authorization" => "Bearer #{jwt}", "Content-Type" => "application/json",
       "Accept" => "application/json"}
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
