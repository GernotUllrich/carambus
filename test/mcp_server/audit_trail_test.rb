# frozen_string_literal: true

require "test_helper"
require "tempfile"

# Tests für McpServer::AuditTrail Module (Plan 10-05.1 Task 1 / D-10-04-D).
# Verifiziert JSON-Lines-Schema (7 Felder), Append-Modus, Defensive-Failure-Pattern.
class McpServer::AuditTrailTest < ActiveSupport::TestCase
  setup do
    # Test-isolated log path — verhindert Pollution von log/mcp-audit-trail.log
    @tmp_log_path = "#{Dir.tmpdir}/mcp-audit-trail-test-#{Process.pid}-#{Time.now.to_f}.log"
    # Stub log_path mit explicitem Pfad — singleton_method-Override
    path = @tmp_log_path
    McpServer::AuditTrail.singleton_class.send(:define_method, :log_path) { path }
  end

  teardown do
    File.unlink(@tmp_log_path) if File.exist?(@tmp_log_path)
    # Restore default log_path
    McpServer::AuditTrail.singleton_class.send(:define_method, :log_path) do
      Rails.root.join("log", "mcp-audit-trail.log").to_s
    end
  end

  test "write_entry: schreibt JSON-Lines mit 7-Feld-Schema" do
    entry = McpServer::AuditTrail.write_entry(
      tool_name: "cc_register_for_tournament",
      operator: "test-user",
      payload: {meldeliste_cc_id: 1310, player_cc_id: 10031},
      pre_validation_results: [{name: "meldeliste_exists", ok: true}],
      read_back_status: "match",
      result: "success"
    )

    refute_nil entry, "write_entry sollte entry-Hash zurückgeben"
    assert_equal "cc_register_for_tournament", entry[:tool]
    assert_equal "test-user", entry[:operator]
    assert_equal "match", entry[:read_back_status]
    assert_equal "success", entry[:result]
    assert_kind_of String, entry[:zeitpunkt]

    # File wurde geschrieben mit JSON-Lines-Format
    content = File.read(@tmp_log_path)
    parsed = JSON.parse(content.strip)
    %w[zeitpunkt operator tool payload pre_validation_results read_back_status result].each do |key|
      assert parsed.key?(key), "JSON-Lines-Entry muss key '#{key}' enthalten"
    end
  end

  test "write_entry: append-Modus — mehrere Einträge stapeln sich" do
    3.times do |i|
      McpServer::AuditTrail.write_entry(
        tool_name: "cc_test_tool",
        operator: "op-#{i}",
        payload: {iteration: i},
        pre_validation_results: [],
        read_back_status: "skipped",
        result: "success"
      )
    end

    lines = File.readlines(@tmp_log_path)
    assert_equal 3, lines.length, "3 write_entry-Calls sollten 3 JSON-Lines erzeugen"
    lines.each_with_index do |line, i|
      parsed = JSON.parse(line)
      assert_equal "op-#{i}", parsed["operator"]
      assert_equal i, parsed["payload"]["iteration"]
    end
  end

  test "write_entry: defensive bei File-System-Failure (rescue, kein Crash)" do
    # Override log_path to non-writable location
    bad_path = "/proc/cannot-create-this-path/audit.log"
    McpServer::AuditTrail.singleton_class.send(:define_method, :log_path) { bad_path }

    result = nil
    assert_nothing_raised do
      result = McpServer::AuditTrail.write_entry(
        tool_name: "cc_test_tool",
        operator: "test",
        payload: {},
        pre_validation_results: [],
        read_back_status: "skipped",
        result: "success"
      )
    end

    assert_nil result, "Bei Logger-Failure muss write_entry nil zurückgeben (defensive)"
  end

  test "write_entry: operator-Fallback auf 'unknown' bei leerem String" do
    entry = McpServer::AuditTrail.write_entry(
      tool_name: "cc_test_tool",
      operator: "",
      payload: {},
      pre_validation_results: [],
      read_back_status: nil,
      result: "success"
    )
    refute_nil entry
    assert_equal "unknown", entry[:operator]
  end
end
