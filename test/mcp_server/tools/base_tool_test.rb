# frozen_string_literal: true

require "test_helper"

# Smoke-Tests für BaseTool-Helpers, die in Plan 10-05 hinzugefügt wurden.
class McpServer::Tools::BaseToolTest < ActiveSupport::TestCase
  # Plan 10-05 Task 4 (Befund #8 D-10-03-5): format_pre_read_status Helper für 5 Write-Tools.
  test "format_pre_read_status: liefert verified + source Felder (DRY pre-read status)" do
    status = McpServer::Tools::BaseTool.format_pre_read_status(verified: true, source: "DB-resolver")
    assert_equal true, status[:pre_read_verified]
    assert_equal "DB-resolver", status[:pre_read_source]
    refute status.key?(:pre_read_warning), "warning nur present wenn explicit gesetzt"
  end

  test "format_pre_read_status: warning ergänzt wenn gesetzt" do
    status = McpServer::Tools::BaseTool.format_pre_read_status(
      verified: false,
      source: "override-param",
      warning: "meldeliste_cc_id=1310 ungeprüft als Override"
    )
    assert_equal false, status[:pre_read_verified]
    assert_equal "override-param", status[:pre_read_source]
    assert_equal "meldeliste_cc_id=1310 ungeprüft als Override", status[:pre_read_warning]
  end

  test "format_pre_read_status: source-Werte sind dokumentierte Strings (DB-resolver/live-CC-fallback/override-param)" do
    %w[DB-resolver live-CC-fallback override-param].each do |src|
      status = McpServer::Tools::BaseTool.format_pre_read_status(verified: true, source: src)
      assert_equal src, status[:pre_read_source]
    end
  end

  # Plan 10-05.1 Task 1 (D-10-04-G Pre-Validation-Framework):
  test "run_validations: all-passed Case (alle Constraints ok)" do
    validations = [
      {name: "constraint_a", ok: true},
      {name: "constraint_b", ok: true}
    ]
    result = McpServer::Tools::BaseTool.run_validations(validations)
    assert_equal true, result[:all_passed]
    assert_equal 2, result[:results].length
    assert_empty result[:failed_constraints]
  end

  test "run_validations: mixed Case mit 1 failed Constraint" do
    validations = [
      {name: "constraint_a", ok: true},
      {name: "constraint_b", ok: false, reason: "test failure reason"}
    ]
    result = McpServer::Tools::BaseTool.run_validations(validations)
    assert_equal false, result[:all_passed]
    assert_equal ["constraint_b"], result[:failed_constraints]
    failed = result[:results].find { |r| !r[:ok] }
    assert_equal "test failure reason", failed[:reason]
  end

  test "run_validations: lambda-Validations werden lazy evaluated" do
    eager_calls = 0
    lazy_called = false

    validations = [
      {name: "eager", ok: true}.tap { eager_calls += 1 },
      -> {
        lazy_called = true
        {name: "lazy", ok: true}
      }
    ]
    result = McpServer::Tools::BaseTool.run_validations(validations)

    assert_equal true, result[:all_passed]
    assert_equal 2, result[:results].length
    assert lazy_called, "Lambda-Validation muss aufgerufen worden sein"
  end
end
