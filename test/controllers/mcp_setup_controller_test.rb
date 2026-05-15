# frozen_string_literal: true

require "test_helper"

# Integration-Tests für McpSetupController (Plan 14-01.5).
# Testet Devise-Auth-Gate + Token-Generation + Cache-Control + JWT-Decodability.
class McpSetupControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "mcp_setup_test@example.com",
      password: "password123",

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
end
