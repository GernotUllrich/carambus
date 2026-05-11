# frozen_string_literal: true

require "test_helper"

class McpServer::Tools::SearchPlayerTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    McpServer::CcSession.reset!
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
  end

  test "live-only: triggers MockClient call (no DB lookup)" do
    response = McpServer::Tools::SearchPlayer.call(query: "Mustermann", server_context: nil)
    refute response.error?
    body = response.content.first[:text]
    assert(body.length.positive?)
    assert_match(/Mustermann/, body)
  end

  test "validation: query too short returns error" do
    response = McpServer::Tools::SearchPlayer.call(query: "M", server_context: nil)
    assert response.error?
    assert_match(/at least 2|too short|min/i, response.content.first[:text])
  end

  test "validation: missing query returns error" do
    response = McpServer::Tools::SearchPlayer.call(server_context: nil)
    assert response.error?
  end
end
