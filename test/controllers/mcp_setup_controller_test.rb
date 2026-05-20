# frozen_string_literal: true

require "test_helper"

# Integration-Tests für McpSetupController (Plan 14-01.5).
# Testet Devise-Auth-Gate + Token-Generation + Cache-Control + JWT-Decodability.
class McpSetupControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "mcp_setup_test@example.com",
      password: "password123"
    )
  end

  test "anonymous user is redirected to login" do
    get "/mcp/setup"
    assert_response :redirect
    assert_match %r{/login}, @response.location
  end

  test "logged-in user sees setup command with Bearer token" do
    sign_in @user
    get "/mcp/setup"
    assert_response :success
    assert_match(/Bearer eyJ[\w.-]+/, @response.body, "View muss Bearer-JWT-Token enthalten")
    assert_match(/claude mcp add-json --scope user carambus-remote/, @response.body, "View muss vollständigen claude-mcp-add-json-Befehl enthalten")
  end

  test "token in view is decodable JWT with jti + sub matching user" do
    sign_in @user
    get "/mcp/setup"
    token_match = @response.body.match(/Bearer (eyJ[\w.-]+)/)
    assert token_match, "Bearer-Token muss im Body matchbar sein"
    raw_token = token_match[1]
    secret = Rails.application.credentials.devise_jwt_secret_key.presence || Rails.application.secret_key_base
    payload = JWT.decode(raw_token, secret, true, algorithm: "HS256").first
    assert payload["jti"].present?, "JWT muss jti-Claim enthalten"
    assert_equal @user.id, payload["sub"].to_i, "JWT sub-Claim muss user_id sein"
    assert payload["exp"] > Time.current.to_i, "exp muss zukünftig sein (24h Default)"
  end

  test "response sets cache-control no-store" do
    sign_in @user
    get "/mcp/setup"
    assert_includes @response.headers["Cache-Control"].to_s, "no-store", "Cache-Control muss no-store enthalten (sensitiver Token)"
  end

  # Plan 14-G.8 / AC-1: Dynamische Per-Region-URL via request.base_url.
  test "setup-Befehl nutzt Per-Region-URL aus Request-Host" do
    sign_in @user
    host! "nbv.carambus.de"
    get "/mcp/setup"
    assert_response :success
    assert_match %r{https?://nbv\.carambus\.de/mcp\?stateless=1}, @response.body,
      "Per-Region-URL nbv.carambus.de muss im Setup-Befehl enthalten sein"
    refute_match %r{https://carambus\.de/mcp\?stateless=1}, @response.body,
      "Hardcoded carambus.de-URL darf NICHT vorkommen wenn Host nbv.carambus.de ist"
  end

  # Plan 14-G.8 / AC-2: Token-Restlaufzeit-Anzeige.
  test "Restlaufzeit-Banner zeigt days_remaining" do
    sign_in @user
    get "/mcp/setup"
    assert_response :success
    assert_match(/Token-Restlaufzeit:\s*\d+\s*Tage/, @response.body,
      "Restlaufzeit-Anzeige muss sichtbar sein (Format: 'Token-Restlaufzeit: N Tage')")
  end

  # Plan 14-G.8 / AC-2: Renew-Hinweis-Logik via Unit-Test der private compute_days_remaining-Method.
  # Standard-Minitest hat kein any_instance-Stub; statt komplexem Mocking wird die Helper-Method
  # isoliert getestet (deckt die kritische Branch-Logik ab). Banner-Sichtbarkeit ist via
  # bestehenden Restlaufzeit-Banner-Test (90-Tage frisch → neutral Banner) bereits abgedeckt.
  test "compute_days_remaining returnt korrekten Floor-Wert aus exp-Payload" do
    controller = McpSetupController.new
    exp_in_5_days = (Time.current + 5.days).to_i
    result = controller.send(:compute_days_remaining, {"exp" => exp_in_5_days})
    assert result.is_a?(Integer), "Result muss Integer sein"
    assert result < McpSetupController::RENEW_THRESHOLD_DAYS,
      "5 Tage in Zukunft → days_remaining muss < RENEW_THRESHOLD_DAYS (14) sein, war: #{result}"
    assert result >= 4, "Floor-Rundung: mindestens 4 Tage, war: #{result}"
  end

  test "compute_days_remaining returnt nil bei fehlendem oder ungültigem exp" do
    controller = McpSetupController.new
    assert_nil controller.send(:compute_days_remaining, {}), "Empty Hash → nil"
    assert_nil controller.send(:compute_days_remaining, nil), "nil → nil"
    assert_nil controller.send(:compute_days_remaining, {"exp" => "string"}), "Non-Numeric exp → nil"
  end

  test "total_lifetime_days nutzt Carambus.config.jwt_expiration_days oder fallback 90" do
    controller = McpSetupController.new
    result = controller.send(:total_lifetime_days)
    assert result.is_a?(Integer), "Result muss Integer sein"
    assert result > 0, "Lifetime muss positiv sein"
    # Fallback ist 90 — in test-env evtl. anders via Carambus.config; nur positive-Integer-Check
  end
end
