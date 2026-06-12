# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/mcp_server/tools/base_tool"
Dir[Rails.root.join("lib/mcp_server/tools/*.rb")].each { |f| require f }

# Phase 36-02: cc_smart_search — wrappt AiSearchService (Service gemockt, key-frei).
class SmartSearchTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "smartsearch@test.de", password: "password123")
    @ctx = {user_id: @user.id}
  end

  def call(**kw)
    McpServer::Tools::SmartSearch.call(server_context: @ctx, **kw)
  end

  test "blank query → Fehler" do
    assert call(query: "").error?
  end

  test "Service-Erfolg → entity + path als Text" do
    canned = {success: true, entity: "tournaments", filters: "Discipline:Dreiband Season:2024/2025",
              path: "/tournaments?sSearch=Discipline:Dreiband", explanation: "Dreiband-Turniere 2024", confidence: 90}
    AiSearchService.stub(:call, canned) do
      res = call(query: "Dreiband Turniere 2024")
      assert_not res.error?
      body = JSON.parse(res.content.first[:text])
      assert_equal "tournaments", body["entity"]
      assert_match %r{/tournaments}, body["path"]
    end
  end

  test "Service-Fehler → Fehler-Response" do
    AiSearchService.stub(:call, {success: false, error: "KI-Suche nicht konfiguriert"}) do
      res = call(query: "irgendwas")
      assert res.error?
    end
  end
end
