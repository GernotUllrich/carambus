# frozen_string_literal: true

require "test_helper"

class McpServer::Resources::WorkflowScenariosTest < ActiveSupport::TestCase
  # Plan 03-02 Drift-Guard-Update: 3 → 4 Scenarios (neuer JSON-Spickzettel anmeldung-aus-email).
  # Plan 03-03 Drift-Guard-Update: 4 → 5 Scenarios (neuer JSON-Spickzettel meldeliste-finalisieren).
  # Plan 05-03 Drift-Guard-Update: 5 → 6 Scenarios (neuer JSON-Spickzettel turnier-status-und-anmelden).
  # mime_type ist jetzt variabel pro Slug; .read gibt Hash {content:, mime_type:} zurück.
  EXPECTED_SCENARIO_COUNT = 6

  test "all gibt 6 MCP::Resource-Instanzen zurück" do
    resources = McpServer::Resources::WorkflowScenarios.all
    assert_equal EXPECTED_SCENARIO_COUNT, resources.size
    assert resources.all? { |r| r.is_a?(MCP::Resource) }
  end

  test "alle URIs entsprechen cc://workflow/scenarios/{slug}" do
    McpServer::Resources::WorkflowScenarios.all.each do |r|
      assert_match %r{\Acc://workflow/scenarios/[\w-]+\z}, r.uri
    end
  end

  test "Markdown-Scenarios haben mime_type text/markdown" do
    markdown_slugs = %w[teilnehmerliste-finalisieren player-anlegen endrangliste-eintragen]
    markdown_resources = McpServer::Resources::WorkflowScenarios.all.select do |r|
      markdown_slugs.any? { |slug| r.uri.end_with?(slug) }
    end
    assert_equal 3, markdown_resources.size
    assert markdown_resources.all? { |r| r.mime_type == "text/markdown" }
  end

  test "JSON-Spickzettel anmeldung-aus-email hat mime_type application/json" do
    json_resource = McpServer::Resources::WorkflowScenarios.all.find do |r|
      r.uri == "cc://workflow/scenarios/anmeldung-aus-email"
    end
    refute_nil json_resource
    assert_equal "application/json", json_resource.mime_type
  end

  test "read(slug:) gibt Hash mit content + mime_type für gültigen Markdown-Slug zurück" do
    result = McpServer::Resources::WorkflowScenarios.read(slug: "teilnehmerliste-finalisieren")
    assert_kind_of Hash, result
    assert_equal "text/markdown", result[:mime_type]
    assert_match(/\A# /, result[:content])  # beginnt mit H1
    refute_match(/Datei fehlt/, result[:content])
  end

  test "read(slug:) gibt JSON-content + application/json mime_type für anmeldung-aus-email" do
    result = McpServer::Resources::WorkflowScenarios.read(slug: "anmeldung-aus-email")
    assert_kind_of Hash, result
    assert_equal "application/json", result[:mime_type]
    parsed = JSON.parse(result[:content])
    assert_equal "anmeldung-aus-email", parsed["id"]
  end

  test "read(slug:) gibt Not-Found-Hash für unbekannten Slug zurück (keine Exception)" do
    result = McpServer::Resources::WorkflowScenarios.read(slug: "nonexistent")
    assert_kind_of Hash, result
    assert_match(/Scenario nicht gefunden/, result[:content])
  end

  test "server.build enthält WorkflowScenarios in der Resource-Liste" do
    server = McpServer::Server.build
    scenario_uris = server.resources.select { |r| r.uri.start_with?("cc://workflow/scenarios/") }.map(&:uri)
    assert_equal EXPECTED_SCENARIO_COUNT, scenario_uris.size
    assert_includes scenario_uris, "cc://workflow/scenarios/teilnehmerliste-finalisieren"
    assert_includes scenario_uris, "cc://workflow/scenarios/anmeldung-aus-email"
    assert_includes scenario_uris, "cc://workflow/scenarios/turnier-status-und-anmelden"
    assert_includes scenario_uris, "cc://workflow/scenarios/meldeliste-finalisieren"
  end

  # Plan 03-03 Bonus-Test: bestätigt, dass alle JSON-Spickzettel korrekt registriert sind.
  # Plan 05-03 Drift-Guard-Update: 2 → 3 JSON-Spickzettel (neuer Slug turnier-status-und-anmelden).
  test "alle JSON-Spickzettel haben mime_type application/json" do
    json_resources = McpServer::Resources::WorkflowScenarios.all.select { |r| r.mime_type == "application/json" }
    assert_equal 3, json_resources.size
    assert_includes json_resources.map(&:uri), "cc://workflow/scenarios/anmeldung-aus-email"
    assert_includes json_resources.map(&:uri), "cc://workflow/scenarios/turnier-status-und-anmelden"
    assert_includes json_resources.map(&:uri), "cc://workflow/scenarios/meldeliste-finalisieren"
  end
end
