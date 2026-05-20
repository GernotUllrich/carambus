# frozen_string_literal: true

require "test_helper"

# Plan 17-02: Controller-Tests fuer die neuen Lifecycle-Endpoints (tournament create, lock_table)
# + tables-Discovery-Erweiterung (locked_for_tournament). Auth-Muster wie Phase 15.
module Api
  class ExternalTournamentsLifecycleTest < ActionDispatch::IntegrationTest
    setup do
      @nbv = regions(:nbv)
      @location = locations(:one)
      @service_user = User.create!(email: "test-2band-lifecycle@carambus.de", password: "password123")
    end

    teardown do
      Tournament.where(region_id: @nbv.id, external_id: %w[ep-1]).each do |t|
        t.tournament_monitor&.destroy
        t.destroy
      end
      User.where(email: "test-2band-lifecycle@carambus.de").delete_all
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

    private

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
