# frozen_string_literal: true
require "test_helper"

class McpServer::Tools::LookupRegionTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    ENV["CC_FED_ID"] = nil  # Pin auf nil damit "force_refresh requires fed_id"-Test stabil bleibt
    McpServer::CcSession.reset!
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    ENV["CC_FED_ID"] = nil
  end

  test "DB-first happy path: returns region by shortname" do
    region = Region.first
    skip "No region fixtures loaded" unless region
    response = McpServer::Tools::LookupRegion.call(shortname: region.shortname, server_context: nil)
    refute response.error?
    body = response.content.first[:text]
    assert_match(/#{region.shortname}/i, body)
  end

  test "DB-first miss: returns not-found error response" do
    response = McpServer::Tools::LookupRegion.call(shortname: "ZZZ-IMPOSSIBLE-#{SecureRandom.hex(4)}", server_context: nil)
    assert response.error?
    assert_match(/not found/i, response.content.first[:text])
  end

  test "validation: missing both shortname and fed_id returns error" do
    response = McpServer::Tools::LookupRegion.call(server_context: nil)
    assert response.error?
    assert_match(/Missing required parameter|provide at least one/i, response.content.first[:text])
  end

  test "force_refresh requires fed_id" do
    response = McpServer::Tools::LookupRegion.call(shortname: "BCW", force_refresh: true, server_context: nil)
    assert response.error?
    assert_match(/fed_id/i, response.content.first[:text])
  end
end
