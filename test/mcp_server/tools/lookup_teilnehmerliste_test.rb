# frozen_string_literal: true

require "test_helper"

class McpServer::Tools::LookupTeilnehmerlisteTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    McpServer::CcSession.reset!
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
  end

  test "D-18 acceptance story: lookup by tournament_id returns structured response" do
    tournament = Tournament.first
    skip "No tournament fixtures loaded" unless tournament
    response = McpServer::Tools::LookupTeilnehmerliste.call(tournament_id: tournament.id, server_context: nil)
    body = response.content.first[:text]
    assert(body.length.positive?)
  end

  test "unknown tournament_id returns error response" do
    response = McpServer::Tools::LookupTeilnehmerliste.call(tournament_id: 999_999_999, server_context: nil)
    assert response.error?
  end

  test "missing required params returns validation error" do
    response = McpServer::Tools::LookupTeilnehmerliste.call(server_context: nil)
    assert response.error?
    # Plan 14-02.3 / F-6: Sportwart-Vokabular im Error-Message.
    assert_match(/tournament_id|meldeliste_id/i, response.content.first[:text])
    assert_match(/Bitte gib|gib `/i, response.content.first[:text])
  end
end
