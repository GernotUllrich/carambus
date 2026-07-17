# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/mcp_server/tools/base_tool"
Dir[Rails.root.join("lib/mcp_server/tools/*.rb")].each { |f| require f }

# Phase 36-02: cc_doc_search — wrappt AiDocsService (Service gemockt, key-frei).
class DocSearchTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "docsearch@test.de", password: "password123")
    @ctx = {user_id: @user.id}
  end

  def call(**kw)
    McpServer::Tools::DocSearch.call(server_context: @ctx, **kw)
  end

  test "blank query → Fehler" do
    assert call(query: "  ").error?
  end

  test "Service-Erfolg → Antwort als Text" do
    canned = {success: true, answer: "So legst du ein Turnier an.",
              docs_links: [{title: "Turniere", url: "/docs/x"}], snippets: [], confidence: 80}
    AiDocsService.stub(:call, canned) do
      res = call(query: "Wie lege ich ein Turnier an?")
      assert_not res.error?
      body = JSON.parse(res.content.first[:text])
      assert_equal "So legst du ein Turnier an.", body["answer"]
      assert_equal 80, body["confidence"]
    end
  end

  test "Service-Fehler → Fehler-Response" do
    AiDocsService.stub(:call, {success: false, error: "KI-Dokumentations-Suche nicht konfiguriert"}) do
      res = call(query: "Frage")
      assert res.error?
      assert_match(/nicht konfiguriert/i, res.content.first[:text])
    end
  end
end
