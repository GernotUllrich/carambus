# frozen_string_literal: true

require "test_helper"

class McpServer::Resources::ContextCurrentTest < ActiveSupport::TestCase
  test ".all liefert genau 1 MCP::Resource mit URI context://current und mime_type application/json" do
    resources = McpServer::Resources::ContextCurrent.all
    assert_equal 1, resources.size
    res = resources.first
    assert_equal "context://current", res.uri
    assert_equal "context-current", res.name
    assert_equal "application/json", res.mime_type
  end

  test ".read liefert Hash mit content + mime_type — content ist JSON-parsbar" do
    result = McpServer::Resources::ContextCurrent.read(uri: "context://current")
    assert result.is_a?(Hash)
    assert result.key?(:content)
    assert result.key?(:mime_type)
    assert_equal "application/json", result[:mime_type]

    body = JSON.parse(result[:content])
    # Minimal-Form: scenario_name + region + default_season; user-Felder nil/[]
    assert body.key?("scenario_name")
    assert body.key?("region")
    assert body.key?("default_season")
    assert_nil body["user"], "Resource-Read has no auth-context — user must be nil"
    assert_equal [], body["sportwart_locations"]
    assert_equal [], body["sportwart_disciplines"]
  end

  test ".read ist konsistent mit cc_whoami.call(server_context: nil) — identische Schlüssel" do
    resource_result = McpServer::Resources::ContextCurrent.read(uri: "context://current")
    tool_result = McpServer::Tools::CcWhoami.call(server_context: nil)

    resource_body = JSON.parse(resource_result[:content])
    tool_body = JSON.parse(tool_result.content.first[:text])

    # Schlüssel identisch; user-Felder beide nil/[] (Resource hat keinen Auth-Context,
    # Tool hier auch nicht weil server_context: nil)
    assert_equal tool_body.keys.sort, resource_body.keys.sort
    assert_equal tool_body["scenario_name"], resource_body["scenario_name"]
    assert_equal tool_body["default_season"], resource_body["default_season"]
  end
end
