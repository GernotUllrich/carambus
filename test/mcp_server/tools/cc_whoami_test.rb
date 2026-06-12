# frozen_string_literal: true

require "test_helper"

class McpServer::Tools::CcWhoamiTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    @original_scenarioname = ENV["scenarioname"]
    @original_scenario_name = ENV["SCENARIO_NAME"]
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    ENV["scenarioname"] = @original_scenarioname
    ENV["SCENARIO_NAME"] = @original_scenario_name
  end

  test "minimal-Scope: ohne server_context liefert scenario_name + region + default_season + nil-user + leere sportwart-Arrays" do
    response = McpServer::Tools::CcWhoami.call(server_context: nil)
    refute response.error?, "Tool should not error on minimal-call"

    body = JSON.parse(response.content.first[:text])

    # Pflicht-Felder vorhanden
    assert body.key?("scenario_name"), "scenario_name missing"
    assert body.key?("region"), "region key missing (may be nil)"
    assert body.key?("default_season"), "default_season key missing"
    assert_equal({}, body.slice("encrypted_cc_credentials", "password_digest", "cc_credentials"),
      "sensitive fields must NEVER leak in output")

    # user-Felder im no-server_context-Fall: nil + []
    assert_nil body["user"], "user must be nil without server_context"
    assert_equal [], body["sportwart_locations"], "sportwart_locations empty without server_context"
    assert_equal [], body["sportwart_disciplines"], "sportwart_disciplines empty without server_context"
  end

  test "scenario_name resolution: ENV[scenarioname] hat Vorrang" do
    ENV["scenarioname"] = "carambus_test_scenario"
    response = McpServer::Tools::CcWhoami.call(server_context: nil)
    body = JSON.parse(response.content.first[:text])
    assert_equal "carambus_test_scenario", body["scenario_name"]
  end

  test "scenario_name resolution: SCENARIO_NAME als Fallback wenn scenarioname leer" do
    ENV["scenarioname"] = nil
    ENV["SCENARIO_NAME"] = "carambus_fallback"
    response = McpServer::Tools::CcWhoami.call(server_context: nil)
    body = JSON.parse(response.content.first[:text])
    assert_equal "carambus_fallback", body["scenario_name"]
  end

  test "scenario_name resolution: Carambus.config.basename als 3. Fallback wenn ENV leer" do
    # Bugfix-Pre-Apply-Verify 2026-05-31: ENV[scenarioname] ist im Puma-Process
    # NICHT gesetzt (nur in Capistrano-Cron-Context). Carambus.config.basename
    # ist die kanonische Scenario-Identität (carambus_nbv hat basename: "carambus_nbv").
    ENV["scenarioname"] = nil
    ENV["SCENARIO_NAME"] = nil
    skip "Carambus.config.basename not defined in this test env" unless Carambus.config.respond_to?(:basename) && Carambus.config.basename.present?

    response = McpServer::Tools::CcWhoami.call(server_context: nil)
    body = JSON.parse(response.content.first[:text])
    assert_equal Carambus.config.basename, body["scenario_name"]
  end

  test "user-scope: mit server_context und valid user_id liefert user + sportwart_locations" do
    user = begin
      users(:admin)
    rescue
      User.first
    end
    skip "No User fixtures loaded" unless user

    response = McpServer::Tools::CcWhoami.call(server_context: {user_id: user.id})
    refute response.error?

    body = JSON.parse(response.content.first[:text])
    assert_equal user.id, body["user"]["id"]
    assert_equal user.email, body["user"]["email"]
    assert body["sportwart_locations"].is_a?(Array), "sportwart_locations is array (may be empty)"
    assert body["sportwart_disciplines"].is_a?(Array), "sportwart_disciplines is array (may be empty)"
  end

  test "rescue-Pfad: stale user_id (non-existing) liefert nil-user statt crash" do
    response = McpServer::Tools::CcWhoami.call(server_context: {user_id: 999_999_999})
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_nil body["user"]
    assert_equal [], body["sportwart_locations"]
    assert_equal [], body["sportwart_disciplines"]
  end

  # Phase 34-02: personas + can_write_cc.
  test "personas + can_write_cc: ohne server_context → [] + false" do
    response = McpServer::Tools::CcWhoami.call(server_context: nil)
    body = JSON.parse(response.content.first[:text])
    assert_equal [], body["personas"]
    assert_equal false, body["can_write_cc"]
  end

  test "personas + can_write_cc: system_admin → personas enthält system_admin, can_write_cc true" do
    admin = User.create!(email: "whoami_admin@test.de", password: "password123", role: :system_admin)
    response = McpServer::Tools::CcWhoami.call(server_context: {user_id: admin.id})
    body = JSON.parse(response.content.first[:text])
    assert_includes body["personas"], "system_admin"
    assert_equal true, body["can_write_cc"]
  end

  test "personas + can_write_cc: reiner player → personas [player], can_write_cc false" do
    player = User.create!(email: "whoami_player@test.de", password: "password123")
    response = McpServer::Tools::CcWhoami.call(server_context: {user_id: player.id})
    body = JSON.parse(response.content.first[:text])
    assert_equal ["player"], body["personas"]
    assert_equal false, body["can_write_cc"]
  end
end
