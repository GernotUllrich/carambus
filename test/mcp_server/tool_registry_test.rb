# frozen_string_literal: true

require "test_helper"
require_relative "../../lib/mcp_server/tool_registry"
require_relative "../../lib/mcp_server/tools/base_tool"
Dir[Rails.root.join("lib/mcp_server/tools/*.rb")].each { |f| require f }

# Phase 34-01 (v1.0): ToolRegistry vom Stub (jeder User → ALL_TOOLS) auf
# persona-basiertes Gating umgestellt. Read-Tools für alle; Write-Tools nur für
# cc_write_access? (Sportwart + Turnierleiter + system_admin).
# Per-Record-Authority bleibt orthogonal in BaseTool.authorize! (14-G.2).
class McpServer::ToolRegistryTest < ActiveSupport::TestCase
  test "tools_for(nil) liefert leeres Array (defensive Default)" do
    assert_equal [], McpServer::ToolRegistry.tools_for(nil)
  end

  test "read-only Persona (cc_write_access? false): nur BASE_READ_TOOLS, KEIN Write-Tool" do
    u = User.new(email: "tr-ro@example.com", password: "password123")
    def u.cc_write_access?
      false
    end
    tools = McpServer::ToolRegistry.tools_for(u)
    assert_equal McpServer::RoleToolMap::BASE_READ_TOOLS.sort, tools.sort
    assert((tools & McpServer::RoleToolMap::WRITE_TOOLS).empty?,
      "read-only Persona darf KEIN Write-Tool bekommen")
  end

  test "schreibberechtigte Persona (cc_write_access? true): Read + Write (ALL_TOOLS)" do
    u = User.new(email: "tr-rw@example.com", password: "password123")
    def u.cc_write_access?
      true
    end
    tools = McpServer::ToolRegistry.tools_for(u)
    assert_equal McpServer::RoleToolMap::ALL_TOOLS.sort, tools.sort
    McpServer::RoleToolMap::WRITE_TOOLS.each do |wt|
      assert_includes tools, wt, "Write-Tool #{wt} muss für schreibberechtigte Persona sichtbar sein"
    end
  end

  test "tool_count_for(user) zählt persona-gefiltert" do
    ro = User.new
    def ro.cc_write_access?
      false
    end
    rw = User.new
    def rw.cc_write_access?
      true
    end
    assert_equal McpServer::RoleToolMap::BASE_READ_TOOLS.size, McpServer::ToolRegistry.tool_count_for(ro)
    assert_equal McpServer::RoleToolMap::ALL_TOOLS.size, McpServer::ToolRegistry.tool_count_for(rw)
  end
end
