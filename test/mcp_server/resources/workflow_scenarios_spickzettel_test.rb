# frozen_string_literal: true

require "test_helper"

# Schmoke-Test für JSON-Schema-Spickzettel (Plan 03-02 Task 5).
# Stellt sicher, dass jeder cc://workflow/scenarios/<slug> mit mime_type application/json
# - valides JSON ist
# - die Top-Level-Pflichtfelder enthält
# - jeder Step die Step-Pflichtfelder enthält
# - jeder step.tool entweder existiert oder als Phase-4-Stub markiert ist
# - JSON round-trip-stabil ist
# - in WorkflowScenarios.all mit korrektem mime_type angekündigt wird
#
# Format-Spec: docs/developers/clubcloud-mcp-workflow-scenarios.de.md

class McpServer::Resources::WorkflowScenariosSpickzettelTest < ActiveSupport::TestCase
  REQUIRED_TOP_LEVEL_FIELDS = %w[id version title description user_confirm_strategy steps].freeze
  REQUIRED_STEP_FIELDS = %w[step_id tool params description_for_user].freeze
  PHASE4_STUB_TOOL = "cc_register_for_tournament"

  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
  end

  # Helper — sammelt alle Slugs, die als JSON-Spickzettel registriert sind.
  def json_spickzettel_slugs
    McpServer::Resources::WorkflowScenarios::SCENARIOS.select do |_slug, raw|
      raw.is_a?(Hash) && raw[:mime_type] == "application/json"
    end.keys
  end

  # Helper — alle existierenden MCP-Tool-Namen.
  def existing_tool_names
    McpServer::Tools.constants
      .map { |c| McpServer::Tools.const_get(c) }
      .select { |k| k.is_a?(Class) && k < MCP::Tool }
      .map(&:tool_name)
  end

  test "Check 1: anmeldung-aus-email returns valid JSON" do
    result = McpServer::Resources::WorkflowScenarios.read(slug: "anmeldung-aus-email")
    assert_kind_of Hash, result
    assert_nothing_raised { JSON.parse(result[:content]) }
  end

  test "Check 1b: turnier-status-und-anmelden returns valid JSON" do
    result = McpServer::Resources::WorkflowScenarios.read(slug: "turnier-status-und-anmelden")
    assert_kind_of Hash, result
    assert_nothing_raised { JSON.parse(result[:content]) }
  end

  test "Check 2: spickzettel has all required top-level fields" do
    json_spickzettel_slugs.each do |slug|
      result = McpServer::Resources::WorkflowScenarios.read(slug: slug)
      data = JSON.parse(result[:content])
      REQUIRED_TOP_LEVEL_FIELDS.each do |field|
        assert data.key?(field), "Spickzettel '#{slug}' fehlt das Top-Level-Feld '#{field}'"
      end
    end
  end

  test "Check 3: every step has required fields" do
    json_spickzettel_slugs.each do |slug|
      result = McpServer::Resources::WorkflowScenarios.read(slug: slug)
      data = JSON.parse(result[:content])
      data["steps"].each_with_index do |step, idx|
        REQUIRED_STEP_FIELDS.each do |field|
          assert step.key?(field), "Spickzettel '#{slug}' Step #{idx} fehlt das Feld '#{field}'"
        end
      end
    end
  end

  test "Check 4: every step.tool exists in McpServer::Tools or is phase4 stub" do
    tools = existing_tool_names
    json_spickzettel_slugs.each do |slug|
      result = McpServer::Resources::WorkflowScenarios.read(slug: slug)
      data = JSON.parse(result[:content])
      data["steps"].each_with_index do |step, idx|
        tool = step["tool"]
        is_phase4_stub = step["_phase4_stub"] == true && tool == PHASE4_STUB_TOOL
        is_existing = tools.include?(tool)
        assert(
          is_existing || is_phase4_stub,
          "Spickzettel '#{slug}' Step #{idx} (step_id=#{step["step_id"]}) referenziert unbekanntes Tool '#{tool}' " \
          "(weder in McpServer::Tools noch als _phase4_stub: true mit tool='#{PHASE4_STUB_TOOL}' markiert)"
        )
      end
    end
  end

  test "Check 5: spickzettel JSON round-trips" do
    json_spickzettel_slugs.each do |slug|
      result = McpServer::Resources::WorkflowScenarios.read(slug: slug)
      original = JSON.parse(result[:content])
      round_tripped = JSON.parse(JSON.generate(original))
      assert_equal original, round_tripped, "Spickzettel '#{slug}' ist nicht round-trip-stabil"
    end
  end

  test "Check 6: WorkflowScenarios.all sets application/json mime_type for anmeldung-aus-email" do
    resource = McpServer::Resources::WorkflowScenarios.all.find do |r|
      r.uri == "cc://workflow/scenarios/anmeldung-aus-email"
    end
    refute_nil resource, "anmeldung-aus-email Resource sollte in WorkflowScenarios.all gelistet sein"
    assert_equal "application/json", resource.mime_type
  end

  test "Check 6b: WorkflowScenarios.all sets application/json mime_type for turnier-status-und-anmelden" do
    resource = McpServer::Resources::WorkflowScenarios.all.find do |r|
      r.uri == "cc://workflow/scenarios/turnier-status-und-anmelden"
    end
    refute_nil resource, "turnier-status-und-anmelden Resource sollte in WorkflowScenarios.all gelistet sein"
    assert_equal "application/json", resource.mime_type
  end

  test "Check 7 (Bonus): existing markdown scenarios still have text/markdown mime_type (Backwards-Kompatibilität)" do
    markdown_slugs = %w[teilnehmerliste-finalisieren player-anlegen endrangliste-eintragen]
    markdown_slugs.each do |slug|
      resource = McpServer::Resources::WorkflowScenarios.all.find do |r|
        r.uri == "cc://workflow/scenarios/#{slug}"
      end
      refute_nil resource, "Markdown-Scenario '#{slug}' fehlt in WorkflowScenarios.all"
      assert_equal "text/markdown", resource.mime_type, "Markdown-Scenario '#{slug}' hat falschen mime_type"
    end
  end
end
