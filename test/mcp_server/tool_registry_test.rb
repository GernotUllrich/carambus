# frozen_string_literal: true

require "test_helper"
require_relative "../../lib/mcp_server/tool_registry"
# Eager-load BaseTool + alle Tool-Klassen für constantize-Resolution in tool_classes_for
require_relative "../../lib/mcp_server/tools/base_tool"
Dir[Rails.root.join("lib/mcp_server/tools/*.rb")].each { |f| require f }

# MCP Multi-User-Hosting (v0.3, Plan 13-02, D-13-01-D Option-B-Override)
# Tests für lib/mcp_server/tool_registry.rb
class McpServer::ToolRegistryTest < ActiveSupport::TestCase
  test "tools_for(nil) liefert leeres Array (defensive Default)" do
    assert_equal [], McpServer::ToolRegistry.tools_for(nil)
  end

  test "tools_for(user) liefert Array entsprechend user.mcp_role" do
    u = User.new(email: "tr1@example.com", password: "password123", mcp_role: :mcp_admin)
    tools = McpServer::ToolRegistry.tools_for(u)
    assert tools.size > 0
    assert tools.include?(:RegisterForTournament)
    assert tools.include?(:FinalizeTeilnehmerliste)
  end

  test "tool_count_for(nil) = 0 + unbekannte Rolle = 0" do
    assert_equal 0, McpServer::ToolRegistry.tool_count_for(nil)
    assert_equal 0, McpServer::ToolRegistry.tool_count_for(:unknown_role)
  end

  test "tool_count_for(:mcp_public_read) = 16 (Read-Tools-Count)" do
    assert_equal 16, McpServer::ToolRegistry.tool_count_for(:mcp_public_read)
  end

  test "tool_classes_for(user) resolved zu McpServer::Tools::*-Klassen erbend von BaseTool" do
    u = User.new(email: "tr2@example.com", password: "password123", mcp_role: :mcp_admin)
    classes = McpServer::ToolRegistry.tool_classes_for(u)
    assert classes.size > 0, "tool_classes_for sollte ≥1 Klasse liefern"
    classes.each do |c|
      assert c.is_a?(Class), "#{c} ist keine Klasse"
      assert c.ancestors.include?(McpServer::Tools::BaseTool), "#{c} erbt nicht von McpServer::Tools::BaseTool"
    end
  end
end
