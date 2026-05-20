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

  # v0.3 Plan 13-05 (D-13-01-D Multi-User-Filtering): DB-Insert + user_id-Tests.
  # Defense-in-Depth: DB-Tabelle parallel zu JSON-Lines (file bleibt SOURCE-OF-TRUTH-Fallback).

  test "write_entry: persistiert in DB UND JSON-Lines (Defense-in-Depth)" do
    before_count = McpAuditTrail.count
    entry = McpServer::AuditTrail.write_entry(
      tool_name: "cc_register_for_tournament",
      operator: "unknown",
      payload: {meldeliste_cc_id: 1310, armed: true},
      pre_validation_results: [],
      read_back_status: nil,
      result: "success"
    )
    refute_nil entry
    assert_equal before_count + 1, McpAuditTrail.count
    last_db = McpAuditTrail.order(:created_at).last
    assert_equal "cc_register_for_tournament", last_db.tool_name
    assert_equal "success", last_db.result
    assert_equal "unknown", last_db.operator
    # JSON-Lines parallel geschrieben
    content = File.read(@tmp_log_path)
    parsed = JSON.parse(content.strip)
    assert_equal "cc_register_for_tournament", parsed["tool"]
  end

  test "write_entry: user_id wird in DB + JSON-Lines geschrieben (HTTP-Pfad)" do
    user = User.create!(email: "at-http@test.de", password: "password123",)
    entry = McpServer::AuditTrail.write_entry(
      tool_name: "cc_register_for_tournament",
      operator: "carambus_admin",
      payload: {armed: true},
      pre_validation_results: [],
      read_back_status: nil,
      result: "success",
      user_id: user.id
    )
    assert_equal user.id, entry[:user_id]
    last_db = McpAuditTrail.order(:created_at).last
    assert_equal user.id, last_db.user_id
  end

  test "write_entry: ohne user_id (Stdio-Pfad) → user_id=nil in DB" do
    before_count = McpAuditTrail.count
    McpServer::AuditTrail.write_entry(
      tool_name: "cc_test_stdio",
      operator: "stdio_user",
      payload: {armed: true},
      pre_validation_results: [],
      read_back_status: nil,
      result: "success"
    )
    last_db = McpAuditTrail.order(:created_at).last
    assert_equal before_count + 1, McpAuditTrail.count
    assert_nil last_db.user_id
  end

  test "write_entry: DB-Failure crasht nicht — JSON-Lines bleibt (Defense-in-Depth)" do
    # Simuliere DB-Failure via Stub von McpAuditTrail.create!
    McpAuditTrail.stub(:create!, ->(**_kwargs) { raise ActiveRecord::ConnectionNotEstablished, "stubbed for test" }) do
      entry = nil
      assert_nothing_raised do
        entry = McpServer::AuditTrail.write_entry(
          tool_name: "cc_test_db_fail",
          operator: "x",
          payload: {},
          pre_validation_results: [],
          read_back_status: nil,
          result: "success"
        )
      end
      refute_nil entry, "JSON-Lines-Entry sollte trotz DB-Failure zurückgegeben werden"
      assert_equal "cc_test_db_fail", entry[:tool]
    end
  end

  test "write_entry: für_user-Scope filtert pro mcp-User-Login" do
    user_a = User.create!(email: "at-a@test.de", password: "password123",)
    user_b = User.create!(email: "at-b@test.de", password: "password123",)

    3.times do
      McpServer::AuditTrail.write_entry(
        tool_name: "cc_test_filter",
        operator: "x",
        payload: {},
        pre_validation_results: [],
        read_back_status: nil,
        result: "success",
        user_id: user_a.id
      )
    end
    McpServer::AuditTrail.write_entry(
      tool_name: "cc_test_filter",
      operator: "x",
      payload: {},
      pre_validation_results: [],
      read_back_status: nil,
      result: "success",
      user_id: user_b.id
    )

    a_entries = McpAuditTrail.for_user(user_a).for_tool("cc_test_filter")
    b_entries = McpAuditTrail.for_user(user_b).for_tool("cc_test_filter")
    assert_equal 3, a_entries.count
    assert_equal 1, b_entries.count
  end
end
