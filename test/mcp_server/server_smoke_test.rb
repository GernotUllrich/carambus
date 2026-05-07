# frozen_string_literal: true
require "test_helper"

class McpServer::ServerSmokeTest < ActiveSupport::TestCase
  test "build gibt eine MCP::Server-Instanz zurück" do
    server = McpServer::Server.build
    assert_instance_of MCP::Server, server
  end

  test "Server-Name ist carambus_clubcloud" do
    server = McpServer::Server.build
    assert_equal "carambus_clubcloud", server.name
  end

  test "vor Wave-2-Plänen erzeugt build keine Exception (leere Registry sicher)" do
    assert_nothing_raised { McpServer::Server.build }
  end

  test "kein STDOUT-Pollution beim Server-Build (Pitfall 1)" do
    out, _err = capture_io { McpServer::Server.build }
    assert_equal "", out, "Server-Build schrieb auf STDOUT — würde JSON-RPC-Kanal korrumpieren"
  end

  # SDK-API smoke probe (Warning 8 — sperrt die API-Verträge, auf die Plans 04 + 05 aufbauen).
  # Findings werden in Plan 01 SUMMARY für Plans 04/05-Referenz festgehalten.
  test "SDK API smoke — MCP::Tool DSL-Makros vorhanden (tool_name, description, input_schema, annotations)" do
    # MCP::Tool-Subklassen nutzen diese DSL-Makros als Class-level-Methoden. Wir verifizieren sie
    # durch Introspection auf einer Wegwerf-Subklasse.
    klass = Class.new(MCP::Tool)
    %i[tool_name description input_schema annotations].each do |dsl_method|
      assert klass.respond_to?(dsl_method),
             "MCP::Tool-Subklassen müssen auf ##{dsl_method} antworten (DSL-Makro). " \
             "Bei Fehlschlag hat SDK 0.15 eine andere API und Plans 04+05 müssen sich anpassen."
    end
  end

  test "SDK API smoke — MCP::Tool::Response hat #error? und #content" do
    # ACHTUNG: SDK 0.15 exponiert `error?` (Predicate), NICHT `error`.
    # Plans 04+05 müssen `response.error?` verwenden, nicht `response.error`.
    # BaseTool#error und BaseTool#text helper erzeugen korrekte Response-Objekte.
    response = MCP::Tool::Response.new([{ type: "text", text: "hello" }], error: false)
    assert_respond_to response, :error?
    assert_respond_to response, :content
    refute response.error?
    assert_equal "hello", response.content.first[:text]
  end
end
