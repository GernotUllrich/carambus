# frozen_string_literal: true

require "test_helper"
require "yaml"

# NL-Szenario-Harness — datengetriebener Runner für YAML-Szenarien unter
# test/mcp_server/scenarios/cases/.
#
# Phase 1 (Plan 01-01) Skelett: ein Step pro Szenario, einfacher Tool-Call mit
# Erwartungs-Match.
# Phase 2 (Plan 02-02 Task 4) Erweiterung: Multi-Step-Variable-Substitution.
#   - `bind_result: { var_name: "$.json.path" }` pro Step bindet ein Resultat-Feld
#     in eine Variable.
#   - `{{var_name}}` in args wird vor dem Tool-Call substituiert.
#   - JSONPath-Subset: `$.foo`, `$.foo.bar`, `$.foo[0]`, kombiniert.
#   - Opt-in — Single-Step-Szenarien ohne bind_result/{{...}} laufen unverändert.
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
    @prior_fed = ENV["CC_FED_ID"]
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

  # Multi-Step-Erweiterung (Plan 02-02 Task 4) — direkte Tests gegen run_scenario,
  # nicht über YAML, damit die Logik isoliert geprüft werden kann.

  test "Multi-Step: bind_result + var-substitution chains region-lookup -> club-list" do
    skip "NBV fixtures missing" unless Region.find_by(shortname: "NBV")
    skip "Discipline 'Freie Partie klein' missing" unless Discipline.find_by(name: "Freie Partie klein")

    scenario = {
      "mock" => true,
      "steps" => [
        {
          "tool" => "cc_lookup_region",
          "args" => {"shortname" => "NBV"},
          "expect" => {"error" => false},
          "bind_result" => {"region_short" => "$.shortname"}
        },
        {
          "tool" => "cc_list_clubs_by_discipline",
          "args" => {"shortname" => "{{region_short}}", "discipline" => "Freie Partie klein"},
          "expect" => {"error" => false}
        }
      ]
    }
    run_scenario(scenario, "inline-multistep-test")
  end

  test "Multi-Step: unresolved variable raises with clear message" do
    scenario = {
      "mock" => true,
      "steps" => [
        {
          "tool" => "cc_lookup_region",
          "args" => {"shortname" => "{{never_bound}}"},
          "expect" => {"error" => false}
        }
      ]
    }
    err = assert_raises(RuntimeError) { run_scenario(scenario, "inline-unresolved-test") }
    assert_match(/unresolved variable.*never_bound/i, err.message)
  end

  test "Multi-Step: single-step scenario without bind_result works unchanged (backwards-compat)" do
    skip "NBV fixtures missing" unless Region.find_by(shortname: "NBV")

    scenario = {
      "mock" => true,
      "steps" => [
        {
          "tool" => "cc_lookup_region",
          "args" => {"shortname" => "NBV"},
          "expect" => {"error" => false}
        }
      ]
    }
    run_scenario(scenario, "inline-single-step-test")
  end

  test "Multi-Step: dig_jsonpath subset works for simple paths" do
    payload = {"data" => [{"id" => 42, "name" => "first"}, {"id" => 43}], "meta" => {"count" => 2}}
    assert_equal 42, dig_jsonpath(payload, "$.data[0].id", 0, "test", "v")
    assert_equal "first", dig_jsonpath(payload, "$.data[0].name", 0, "test", "v")
    assert_equal 2, dig_jsonpath(payload, "$.meta.count", 0, "test", "v")
  end

  test "Multi-Step: dig_jsonpath raises on nil intermediate" do
    payload = {"data" => nil}
    err = assert_raises(RuntimeError) { dig_jsonpath(payload, "$.data.x", 0, "src", "v") }
    assert_match(/resolves to nil/, err.message)
  end

  private

  def run_scenario(scenario, source)
    steps = Array(scenario["steps"])
    assert steps.any?, "Szenario #{source} hat keine steps"

    tools = McpServer::Server.collect_tools.each_with_object({}) { |k, h| h[k.tool_name] = k }
    bound_vars = {}

    steps.each_with_index do |step, idx|
      tool_name = step["tool"]
      assert tool_name.present?, "Step #{idx} in #{source} ohne tool"

      tool_class = tools[tool_name]
      assert tool_class, "Tool '#{tool_name}' nicht in McpServer::Server.collect_tools registriert (#{source} step #{idx})"

      raw_args = step["args"] || {}
      substituted = substitute_vars(raw_args, bound_vars, idx, source)
      # Plan 14-02.2 / D-14-02-G: strict User-Context — Scenarios sind region-scoped (NBV als Default-Test-Region).
      args = symbolize_keys(substituted).merge(server_context: {cc_region: "NBV"})
      response = tool_class.call(**args)

      expect = step["expect"] || {}
      if expect.key?("error")
        actual_error = response.error?
        assert_equal expect["error"], actual_error,
          "[#{source} step #{idx}] expected error=#{expect["error"]} got #{actual_error}; content=#{content_text(response)}"
      end

      Array(expect["content_includes"]).each do |needle|
        text = content_text(response)
        assert text.include?(needle.to_s),
          "[#{source} step #{idx}] erwarteter Text '#{needle}' nicht in Tool-Antwort gefunden: #{text.inspect}"
      end

      bindings = step["bind_result"] || {}
      if bindings.any?
        json = parse_response_json(response, idx, source)
        bindings.each do |var_name, jsonpath|
          value = dig_jsonpath(json, jsonpath, idx, source, var_name)
          bound_vars[var_name.to_s] = value
        end
      end
    end
  end

  def substitute_vars(obj, vars, idx, source)
    case obj
    when String
      obj.gsub(/\{\{(\w+)\}\}/) do
        var = ::Regexp.last_match(1)
        raise "[#{source} step #{idx}] unresolved variable: #{var}" unless vars.key?(var)
        vars[var].to_s
      end
    when Hash
      obj.each_with_object({}) { |(k, v), h| h[k] = substitute_vars(v, vars, idx, source) }
    when Array
      obj.map { |v| substitute_vars(v, vars, idx, source) }
    else
      obj
    end
  end

  def parse_response_json(response, idx, source)
    text = content_text(response)
    JSON.parse(text)
  rescue JSON::ParserError => e
    raise "[#{source} step #{idx}] response is not JSON: #{e.message}; got: #{text.inspect}"
  end

  # Minimaler JSONPath-Subset: $.foo, $.foo.bar, $.foo[0], kombiniert.
  # KEINE Unterstützung für Wildcards, Slices, Filter — nur dot-walks und numeric indices.
  def dig_jsonpath(node, path, idx, source, var_name)
    unless path.start_with?("$.") || path == "$"
      raise "[#{source} step #{idx}] bind_result for #{var_name}: invalid JSONPath '#{path}' — must start with $."
    end

    segments = path.sub(/\A\$\.?/, "").scan(/[^.\[\]]+|\[\d+\]/).reject(&:empty?)
    cur = node
    segments.each do |seg|
      cur = if seg =~ /\A\[(\d+)\]\z/
        cur.is_a?(Array) ? cur[::Regexp.last_match(1).to_i] : nil
      elsif cur.is_a?(Hash)
        cur[seg] || cur[seg.to_sym]
      end
      if cur.nil?
        raise "[#{source} step #{idx}] bind_result for #{var_name}: path '#{path}' resolves to nil at segment '#{seg}'"
      end
    end
    cur
  end

  def symbolize_keys(hash)
    hash.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
  end

  def content_text(response)
    Array(response.content).map { |c| c[:text] || c["text"] }.compact.join(" ")
  end
end
