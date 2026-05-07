# frozen_string_literal: true
require "test_helper"
require "yaml"

# NL-Szenario-Harness — datengetriebener Runner für YAML-Szenarien unter
# test/mcp_server/scenarios/cases/.
#
# Phase 1 (Plan 01-01) Skelett: ein Step pro Szenario, einfacher Tool-Call mit
# Erwartungs-Match. Phase 2+ erweitert dies um Multi-Step, Rückfragen-Simulation
# und Resource-Reads. Format ist absichtlich minimal — siehe README.md.
#
# Mock-Mode: für jedes Szenario verpflichtend (siehe PROJECT.md hartes Erfolgskriterium
# "kein Prod-Daten-Schaden"). Der Runner prüft `mock: true` im YAML-Header und
# setzt CARAMBUS_MCP_MOCK=1 explizit, sodass Tools über McpServer::CcSession.client_for
# den MockClient erhalten.

module McpServer
  module Scenarios
  end
end

class McpServer::Scenarios::ScenarioRunnerTest < ActiveSupport::TestCase
  CASES_DIR = Rails.root.join("test/mcp_server/scenarios/cases")

  setup do
    @prior_mock = ENV["CARAMBUS_MCP_MOCK"]
    @prior_fed  = ENV["CC_FED_ID"]
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    ENV["CC_FED_ID"] = nil
    McpServer::CcSession.reset!
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = @prior_mock
    ENV["CC_FED_ID"] = @prior_fed
    McpServer::CcSession.reset!
  end

  # Test-Methode pro YAML-Datei dynamisch generieren — Minitest-Konvention.
  # Achtung: define_method läuft bei Class-Load; Tests sind dann Teil der Suite.
  Dir.glob(CASES_DIR.join("*.yml")).sort.each do |yaml_path|
    scenario = YAML.safe_load_file(yaml_path, permitted_classes: [Symbol], aliases: true)
    test_label = scenario["name"] || File.basename(yaml_path, ".yml")
    define_method("test_scenario: #{test_label}") do
      assert scenario["mock"] == true,
             "Szenario #{yaml_path} muss mock: true setzen (Production-Sicherheit)"
      run_scenario(scenario, yaml_path)
    end
  end

  # Fallback-Test, damit die Suite auch ohne YAML-Dateien einen Run hat
  # (verhindert "0 runs"-Misinterpretation als "Tests ignoriert").
  test "scenarios directory contains at least one case file" do
    cases = Dir.glob(CASES_DIR.join("*.yml"))
    assert cases.any?, "Keine YAML-Szenarien in #{CASES_DIR} gefunden"
  end

  private

  def run_scenario(scenario, source)
    steps = Array(scenario["steps"])
    assert steps.any?, "Szenario #{source} hat keine steps"

    tools = McpServer::Server.collect_tools.each_with_object({}) { |k, h| h[k.tool_name] = k }

    steps.each_with_index do |step, idx|
      tool_name = step["tool"]
      assert tool_name.present?, "Step #{idx} in #{source} ohne tool"

      tool_class = tools[tool_name]
      assert tool_class, "Tool '#{tool_name}' nicht in McpServer::Server.collect_tools registriert (#{source} step #{idx})"

      args = symbolize_keys(step["args"] || {}).merge(server_context: nil)
      response = tool_class.call(**args)

      expect = step["expect"] || {}
      if expect.key?("error")
        actual_error = response.error?
        assert_equal expect["error"], actual_error,
                     "[#{source} step #{idx}] expected error=#{expect['error']} got #{actual_error}; content=#{content_text(response)}"
      end

      Array(expect["content_includes"]).each do |needle|
        text = content_text(response)
        assert text.include?(needle.to_s),
               "[#{source} step #{idx}] erwarteter Text '#{needle}' nicht in Tool-Antwort gefunden: #{text.inspect}"
      end
    end
  end

  def symbolize_keys(hash)
    hash.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
  end

  def content_text(response)
    Array(response.content).map { |c| c[:text] || c["text"] }.compact.join(" ")
  end
end
