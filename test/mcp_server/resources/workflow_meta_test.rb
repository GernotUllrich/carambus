# frozen_string_literal: true
require "test_helper"

class McpServer::Resources::WorkflowMetaTest < ActiveSupport::TestCase
  test "all gibt 2 MCP::Resource-Instanzen mit cc://workflow/{roles|glossary}-URIs zurück" do
    resources = McpServer::Resources::WorkflowMeta.all
    assert_equal 2, resources.size
    uris = resources.map(&:uri).sort
    assert_equal ["cc://workflow/glossary", "cc://workflow/roles"], uris
  end

  test "alle Resources haben mime_type text/markdown" do
    assert McpServer::Resources::WorkflowMeta.all.all? { |r| r.mime_type == "text/markdown" }
  end

  test "read(key: 'roles') gibt Markdown mit H1 zurück" do
    content = McpServer::Resources::WorkflowMeta.read(key: "roles")
    assert_match(/\A# /, content)
    refute_match(/Datei fehlt/, content)
  end

  test "read(key: unbekannt) gibt Not-Found-Body ohne Exception zurück" do
    content = McpServer::Resources::WorkflowMeta.read(key: "nope")
    assert_match(/Unknown meta key/, content)
  end

  test "server.build enthält Meta-Resources in der Resource-Liste" do
    server = McpServer::Server.build
    meta_uris = server.resources.map(&:uri).select { |u| u =~ %r{\Acc://workflow/(roles|glossary)\z} }
    assert_equal 2, meta_uris.size
  end
end
