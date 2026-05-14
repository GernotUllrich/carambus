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

  # v0.3 Plan 13-04 (D-13-01-F Backwards-Compat): effective_cc_region Helper mit Fallback-Chain
  # server_context → ENV → Setting → "NBV". UPPERCASE-Convention.
  class EffectiveCcRegionTest < ActiveSupport::TestCase
    setup do
      @original_env = ENV["CC_REGION"]
    end

    teardown do
      ENV["CC_REGION"] = @original_env
    end

    test "effective_cc_region: server_context cc_region wird UPPERCASE zurückgegeben" do
      result = McpServer::Tools::BaseTool.effective_cc_region({cc_region: "bvbw"})
      assert_equal "BVBW", result
    end

    test "effective_cc_region: server_context bekommt Vorrang vor ENV (HTTP > Stdio)" do
      ENV["CC_REGION"] = "nbv"
      result = McpServer::Tools::BaseTool.effective_cc_region({cc_region: "bvbw"})
      assert_equal "BVBW", result, "server_context muss ENV überstimmen"
    end

    test "effective_cc_region: server_context nil → ENV-Fallback (UPPERCASE)" do
      ENV["CC_REGION"] = "nbv"
      result = McpServer::Tools::BaseTool.effective_cc_region(nil)
      assert_equal "NBV", result
    end

    test "effective_cc_region: server_context cc_region nil → ENV-Fallback" do
      ENV["CC_REGION"] = "nbv"
      result = McpServer::Tools::BaseTool.effective_cc_region({cc_region: nil})
      assert_equal "NBV", result
    end

    test "effective_cc_region: server_context cc_region leerer String → ENV-Fallback" do
      ENV["CC_REGION"] = "nbv"
      result = McpServer::Tools::BaseTool.effective_cc_region({cc_region: ""})
      assert_equal "NBV", result
    end

    test "effective_cc_region: kein server_context + kein ENV + kein Setting → Default 'NBV'" do
      ENV.delete("CC_REGION")
      # Setting.key_get_value("context") liefert in dieser Test-DB nil (Fixture-Default)
      result = McpServer::Tools::BaseTool.effective_cc_region(nil)
      assert_equal "NBV", result
    end
  end

  # Plan 14-02.1 / D-14-02-D: resolve_tournament_cc-Helper für (cc_id, context)-Tuple-Lookup.
  # TournamentCc#cc_id ist nur intra-region-eindeutig (User-Klarstellung 2026-05-14).
  class ResolveTournamentCcTest < ActiveSupport::TestCase
    setup do
      ENV.delete("CC_REGION")
      # 2 TournamentCc-Records mit gleicher cc_id, unterschiedlichem context →
      # reproduziert Multi-Region-Production-Szenario (carambus.de hat alle Regionen).
      @nbv_t = TournamentCc.create!(cc_id: 999_001, context: "nbv", name: "Test NBV Tournament")
      @blmr_t = TournamentCc.create!(cc_id: 999_001, context: "blmr", name: "Test BLMR Tournament")
    end

    teardown do
      @nbv_t&.destroy
      @blmr_t&.destroy
    end

    test "resolve_tournament_cc: liefert TournamentCc mit matchendem (cc_id, context)" do
      result = McpServer::Tools::BaseTool.resolve_tournament_cc(
        cc_id: 999_001, server_context: {cc_region: "NBV"}
      )
      assert_equal @nbv_t.id, result&.id
      assert_equal "Test NBV Tournament", result&.name
    end

    test "resolve_tournament_cc: cross-region context → liefert KEIN Match aus anderer Region (Disambiguation)" do
      result = McpServer::Tools::BaseTool.resolve_tournament_cc(
        cc_id: 999_001, server_context: {cc_region: "BLMR"}
      )
      assert_equal @blmr_t.id, result&.id
      refute_equal @nbv_t.id, result&.id, "BLMR-Context darf NICHT NBV-Tournament liefern"
    end

    test "resolve_tournament_cc: cc_id nil → nil (defensive)" do
      result = McpServer::Tools::BaseTool.resolve_tournament_cc(
        cc_id: nil, server_context: {cc_region: "NBV"}
      )
      assert_nil result
    end

    test "resolve_tournament_cc: cc_id ohne Match in Region → nil (cross-region-Mismatch wird NICHT silent fallback)" do
      result = McpServer::Tools::BaseTool.resolve_tournament_cc(
        cc_id: 999_001, server_context: {cc_region: "BVS"}  # Region ohne Match
      )
      assert_nil result, "Cross-Region-Mismatch muss nil liefern, nicht das falsche Tournament"
    end
  end
end
