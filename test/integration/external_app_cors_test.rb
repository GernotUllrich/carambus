# frozen_string_literal: true

require "test_helper"

# Plan 19-01 (v0.6 F2): CORS fuer die externe SPA — nur Bridge-API + /login, expose Authorization,
# LAN-Origins erlaubt, Fremd-Origins blockiert. rack-cors via config/initializers/cors.rb.
class ExternalAppCorsTest < ActionDispatch::IntegrationTest
  LAN_ORIGIN = "http://192.168.178.50:8123"
  FOREIGN_ORIGIN = "https://evil.example"

  test "Preflight von LAN-Origin auf Bridge-API erlaubt + Methods (AC-3)" do
    process :options, "/api/external_tournament/player_rankings",
      headers: {"Origin" => LAN_ORIGIN, "Access-Control-Request-Method" => "GET"}
    assert_equal LAN_ORIGIN, response.headers["Access-Control-Allow-Origin"]
    assert_includes response.headers["Access-Control-Allow-Methods"].to_s.upcase, "GET"
  end

  test "echter cross-origin GET exposed Authorization (AC-3)" do
    # GET ohne Auth -> 401, aber rack-cors setzt die CORS-Header trotzdem (Origin matcht).
    get "/api/external_tournament/player_rankings?region=NBV", headers: {"Origin" => LAN_ORIGIN}
    assert_equal LAN_ORIGIN, response.headers["Access-Control-Allow-Origin"]
    assert_includes response.headers["Access-Control-Expose-Headers"].to_s, "Authorization"
  end

  test "Preflight auf /login von LAN-Origin erlaubt + exposed Authorization (AC-3)" do
    process :options, "/login",
      headers: {"Origin" => LAN_ORIGIN, "Access-Control-Request-Method" => "POST"}
    assert_equal LAN_ORIGIN, response.headers["Access-Control-Allow-Origin"]
    assert_includes response.headers["Access-Control-Expose-Headers"].to_s, "Authorization"
  end

  test "Fremd-Origin wird NICHT erlaubt (AC-3)" do
    process :options, "/api/external_tournament/player_rankings",
      headers: {"Origin" => FOREIGN_ORIGIN, "Access-Control-Request-Method" => "GET"}
    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "CORS NICHT global — Nicht-Bridge-Pfad bekommt kein Allow-Origin (Boundary)" do
    get "/", headers: {"Origin" => LAN_ORIGIN}
    assert_nil response.headers["Access-Control-Allow-Origin"]
  end
end
