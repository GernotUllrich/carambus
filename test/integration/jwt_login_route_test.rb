# frozen_string_literal: true

require "test_helper"

# Plan 13-06.3 (D-13-06.3-A): Schliesst die Test-Luecke aus Plan 13-06.2.
# Die JWT-Tests in mcp_end_to_end_test.rb nutzten Warden::JWTAuth::UserEncoder
# direkt — das umgeht den HTTP-Routing-Pfad komplett. Production-Live-Verify
# auf carambus.de zeigte: POST /users/sign_in ist 404, weil routes.rb via
# `path: ""` + `path_names: { sign_in: "login" }` die echte Route auf /login
# umkonfiguriert. Devise-JWT issued daher gar keinen Token.
#
# Dieser Test trifft die ECHTE HTTP-Route und stellt sicher, dass:
#   1. POST /login mit JSON-Body returniert 200 + Authorization-Header mit Bearer-JWT
#   2. POST /users/sign_in (Devise-Default-Pfad) ist 404 (Routing existiert nicht)
#   3. Param-Filter maskiert Passwoerter rekursiv (auch verschachtelt)
class JwtLoginRouteTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "jwt-login-route@test.de",
      password: "password123",
      mcp_role: :mcp_landessportwart,
      cc_region: "BVBW"
    )
  end

  test "POST /login mit JSON-Credentials liefert 200 + Authorization Bearer-JWT" do
    post "/login",
      params: {user: {email: @user.email, password: "password123"}}.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      }

    assert_response :success, "Login soll 200/201 returnieren — Status war #{response.code}, Body: #{response.body[0..500].inspect}, Location: #{response.headers["Location"].inspect}"
    auth_header = response.headers["Authorization"]
    assert auth_header.present?, "Authorization-Response-Header muss gesetzt sein (devise-jwt dispatch_requests-Regex muss /login matchen)"
    assert auth_header.start_with?("Bearer "), "Authorization-Header soll Bearer-Token enthalten, war: #{auth_header.inspect}"

    token = auth_header.sub(/\ABearer\s+/, "")
    payload = JWT.decode(token, nil, false).first
    assert_equal @user.id.to_s, payload["sub"], "JWT-sub muss User-ID matchen"
    assert payload["jti"].present?, "JWT-jti muss gesetzt sein (Plan 13-06.2 JTIMatcher-Revocation)"
  end

  # Plan 13-06.3 D-13-06.3-C: reproduziert Production-CSRF-Block.
  # Test-Env hat allow_forgery_protection=false per Default — daher hat der
  # vorherige Test den Bug nicht gesehen. Hier explizit re-enablen, sicherstellen
  # dass skip_forgery_protection (if json) den Block fuer JSON-Requests umgeht.
  test "POST /login mit JSON ueberlebt aktivierte CSRF-Protection (skip_forgery_protection if json)" do
    prev = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    begin
      post "/login",
        params: {user: {email: @user.email, password: "password123"}}.to_json,
        headers: {
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
      assert_response :success,
        "Mit aktivierter CSRF-Protection muss SessionsController via skip_forgery_protection (if json) trotzdem 200 liefern. Status: #{response.code}"
      assert response.headers["Authorization"].to_s.start_with?("Bearer "),
        "Authorization-Bearer-Header muss auch unter aktivierter CSRF-Protection gesetzt sein"
    ensure
      ActionController::Base.allow_forgery_protection = prev
    end
  end

  test "POST /users/sign_in (Devise-Default-Pfad) ist 404 — beweist dass routes.rb path-Override aktiv ist" do
    post "/users/sign_in",
      params: {user: {email: @user.email, password: "password123"}}.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      }

    refute response.successful?,
      "Wenn /users/sign_in 2xx returnt, ist routes.rb path_names-Override deaktiviert — dann muss devise.rb dispatch_requests-Regex zurueck auf ^/users/sign_in$. Status war: #{response.code}"
  end

  test "Param-Filter maskiert Passwort rekursiv — schliesst leak via 500-Error-Re-Dispatch" do
    # Plan 13-06.3 D-13-06.3-B: Der ErrorsController re-dispatcht via exceptions_app
    # = routes und kann Original-Params unter [:error]-Key wieder anhaengen.
    # Symbol-basiertes filter_parameters greift nur auf den ersten Hash-Pfad,
    # nicht auf rekursive Tiefe. Lambda-Filter muss auf jeder Tiefe maskieren.

    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter(
      "user" => {"email" => "x@example.com", "password" => "TOP_LEVEL_SECRET"},
      "error" => {
        "user" => {"email" => "x@example.com", "password" => "NESTED_SECRET"}
      }
    )

    assert_equal "[FILTERED]", filtered.dig("user", "password"),
      "Top-Level-Passwort muss maskiert sein"
    assert_equal "[FILTERED]", filtered.dig("error", "user", "password"),
      "Verschachteltes Passwort (3 Ebenen tief) muss AUCH maskiert sein — sonst Leak via 500-Path"

    # Negative-Control: Email darf NICHT maskiert sein (Filter ist auf password-keys eingegrenzt)
    assert_equal "x@example.com", filtered.dig("user", "email"),
      "Email darf nicht maskiert werden (Filter zu greedy)"
  end
end
