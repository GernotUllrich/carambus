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
end
