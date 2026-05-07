# frozen_string_literal: true
require "test_helper"

class McpServer::Resources::WorkflowScenariosTest < ActiveSupport::TestCase
  test "all gibt 3 MCP::Resource-Instanzen zurück" do
    resources = McpServer::Resources::WorkflowScenarios.all
    assert_equal 3, resources.size
    assert resources.all? { |r| r.is_a?(MCP::Resource) }
  end

  test "alle URIs entsprechen cc://workflow/scenarios/{slug}" do
    McpServer::Resources::WorkflowScenarios.all.each do |r|
      assert_match %r{\Acc://workflow/scenarios/[\w-]+\z}, r.uri
    end
  end

  test "alle Resources haben mime_type text/markdown" do
    assert McpServer::Resources::WorkflowScenarios.all.all? { |r| r.mime_type == "text/markdown" }
  end

  test "read(slug:) gibt Disk-Inhalt für gültigen Slug zurück" do
    content = McpServer::Resources::WorkflowScenarios.read(slug: "teilnehmerliste-finalisieren")
    assert_match(/\A# /, content)  # beginnt mit H1
    refute_match(/Datei fehlt/, content)
  end

  test "read(slug:) gibt Not-Found-Body für unbekannten Slug zurück (keine Exception)" do
    content = McpServer::Resources::WorkflowScenarios.read(slug: "nonexistent")
    assert_match(/Scenario nicht gefunden/, content)
  end

  test "server.build enthält WorkflowScenarios in der Resource-Liste" do
    server = McpServer::Server.build
    scenario_uris = server.resources.select { |r| r.uri.start_with?("cc://workflow/scenarios/") }.map(&:uri)
    assert_equal 3, scenario_uris.size
    assert_includes scenario_uris, "cc://workflow/scenarios/teilnehmerliste-finalisieren"
  end
end
