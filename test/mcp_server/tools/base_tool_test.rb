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

    # Plan 14-02.1-fix / D-14-02-G: strict — kein ENV/Setting/NBV-Default-Fallback mehr.
    test "effective_cc_region: server_context cc_region wird UPPERCASE zurückgegeben" do
      result = McpServer::Tools::BaseTool.effective_cc_region({cc_region: "bvbw"})
      assert_equal "BVBW", result
    end

    test "effective_cc_region: server_context nil → nil (strict, kein Fallback)" do
      ENV["CC_REGION"] = "nbv"
      result = McpServer::Tools::BaseTool.effective_cc_region(nil)
      assert_nil result, "Strict-Mode: kein ENV-Fallback erlaubt"
    end

    test "effective_cc_region: server_context cc_region nil → nil (strict)" do
      ENV["CC_REGION"] = "nbv"
      result = McpServer::Tools::BaseTool.effective_cc_region({cc_region: nil})
      assert_nil result, "Strict-Mode: kein ENV-Fallback bei nil cc_region"
    end

    test "effective_cc_region: server_context cc_region leerer String → nil (strict)" do
      ENV["CC_REGION"] = "nbv"
      result = McpServer::Tools::BaseTool.effective_cc_region({cc_region: ""})
      assert_nil result, "Strict-Mode: kein ENV-Fallback bei leerem cc_region"
    end

    test "effective_cc_region: server_context cc_region non-String → nil (strict, defensive)" do
      result = McpServer::Tools::BaseTool.effective_cc_region({cc_region: 123})
      assert_nil result, "Strict-Mode: non-String wird abgelehnt"
    end
  end

  # Plan 14-02.1-fix / D-14-02-G: default_fed_id strict — kein ENV["CC_FED_ID"]-Shortcut;
  # Ableitung via effective_cc_region (jetzt strict) → Region → RegionCc.cc_id.
  class DefaultFedIdTest < ActiveSupport::TestCase
    setup do
      @original_env_region = ENV["CC_REGION"]
      @original_env_fed = ENV["CC_FED_ID"]
      ENV.delete("CC_REGION")
      ENV.delete("CC_FED_ID")
    end

    teardown do
      ENV["CC_REGION"] = @original_env_region
      ENV["CC_FED_ID"] = @original_env_fed
    end

    test "default_fed_id: nil server_context → nil (strict, kein ENV-Shortcut)" do
      ENV["CC_FED_ID"] = "99"
      result = McpServer::Tools::BaseTool.default_fed_id(nil)
      assert_nil result, "Strict-Mode: ENV[CC_FED_ID]-Shortcut entfernt"
    end

    test "default_fed_id: server_context ohne cc_region → nil" do
      result = McpServer::Tools::BaseTool.default_fed_id({cc_region: nil})
      assert_nil result
    end

    test "default_fed_id: server_context mit cc_region → korrekte fed_id via Region-Lookup" do
      region = Region.find_by(shortname: "NBV")
      skip "Region NBV nicht in Test-DB" unless region&.region_cc&.cc_id
      result = McpServer::Tools::BaseTool.default_fed_id({cc_region: "NBV"})
      assert_equal region.region_cc.cc_id, result
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

  # Plan 14-02.2 / Befund E-1: Token-Search-Helper für Title-Präfix-tolerante Name-Suche.
  class TokenizeSearchQueryTest < ActiveSupport::TestCase
    test "tokenize_search_query: empty → []" do
      assert_equal [], McpServer::Tools::BaseTool.tokenize_search_query("")
      assert_equal [], McpServer::Tools::BaseTool.tokenize_search_query(nil)
    end

    test "tokenize_search_query: 'Gernot Ullrich' → ['Gernot', 'Ullrich']" do
      assert_equal ["Gernot", "Ullrich"], McpServer::Tools::BaseTool.tokenize_search_query("Gernot Ullrich")
    end

    test "tokenize_search_query: 'Dr. Gernot Ullrich' → ['Dr.', 'Gernot', 'Ullrich']" do
      assert_equal ["Dr.", "Gernot", "Ullrich"], McpServer::Tools::BaseTool.tokenize_search_query("Dr. Gernot Ullrich")
    end

    test "tokenize_search_query: tokens < 2 chars werden gefiltert" do
      # "G Ullrich" → "G" raus, "Ullrich" bleibt
      assert_equal ["Ullrich"], McpServer::Tools::BaseTool.tokenize_search_query("G Ullrich")
    end

    test "tokenize_search_query: extra Whitespace wird normalisiert" do
      assert_equal ["van", "der", "Bergh"], McpServer::Tools::BaseTool.tokenize_search_query("  van   der  Bergh  ")
    end

    test "detect_title_prefix: 'Dr. Gernot Ullrich' → 'Dr.'" do
      assert_equal "Dr.", McpServer::Tools::BaseTool.detect_title_prefix("Dr. Gernot Ullrich")
    end

    test "detect_title_prefix: 'Prof. Hans' → 'Prof.'" do
      assert_equal "Prof.", McpServer::Tools::BaseTool.detect_title_prefix("Prof. Hans")
    end

    test "detect_title_prefix: kein Title → nil" do
      assert_nil McpServer::Tools::BaseTool.detect_title_prefix("Gernot Ullrich")
    end

    test "apply_token_search_filter: leere tokens → scope unverändert" do
      # Mock-Scope (testet nur, dass keine WHERE-Clause angewandt wird)
      scope = Player.all
      result = McpServer::Tools::BaseTool.apply_token_search_filter(scope, [], %w[firstname])
      assert_equal scope.to_sql, result.to_sql
    end

    test "apply_token_search_filter: 2 tokens → 2 WHERE-Clauses AND-verknüpft" do
      scope = Player.all
      result = McpServer::Tools::BaseTool.apply_token_search_filter(scope, %w[Gernot Ullrich], %w[firstname lastname])
      sql = result.to_sql
      # Beide Tokens müssen als ILIKE-Clauses im SQL erscheinen
      assert_match(/firstname ILIKE.*Gernot/i, sql)
      assert_match(/lastname ILIKE.*Gernot/i, sql)
      assert_match(/firstname ILIKE.*Ullrich/i, sql)
      assert_match(/lastname ILIKE.*Ullrich/i, sql)
    end
  end

  # Plan 14-02.3 / F-7 Season-Default-Helper + F-2 Branch-Resolver-Helper.
  class SeasonAndBranchHelperTest < ActiveSupport::TestCase
    test "effective_season: nil override → current_season" do
      result = McpServer::Tools::BaseTool.effective_season(nil, override: nil)
      assert_equal Season.current_season, result
    end

    test "effective_season: matched override-Name → spezifische Season" do
      season_name = Season.last&.name
      skip "Keine Season-Fixtures vorhanden" if season_name.blank?
      result = McpServer::Tools::BaseTool.effective_season(nil, override: season_name)
      assert_equal season_name, result.name
    end

    test "effective_season: unmatched override → current_season (Fallback)" do
      result = McpServer::Tools::BaseTool.effective_season(nil, override: "9999/0000-nonexistent")
      assert_equal Season.current_season, result
    end

    test "derive_season_from_date: Juli-Datum (2025-08-15) → '2025/2026'" do
      result = McpServer::Tools::BaseTool.derive_season_from_date(Date.new(2025, 8, 15))
      skip "Season '2025/2026' nicht in Test-DB" if result.nil?
      assert_equal "2025/2026", result.name
    end

    test "derive_season_from_date: Juni-Datum (2026-05-15) → '2025/2026'" do
      result = McpServer::Tools::BaseTool.derive_season_from_date(Date.new(2026, 5, 15))
      skip "Season '2025/2026' nicht in Test-DB" if result.nil?
      assert_equal "2025/2026", result.name
    end

    test "derive_season_from_date: Juli-1-Cutoff-Edge — 2025-07-01 → '2025/2026'" do
      result = McpServer::Tools::BaseTool.derive_season_from_date(Date.new(2025, 7, 1))
      skip "Season '2025/2026' nicht in Test-DB" if result.nil?
      assert_equal "2025/2026", result.name
    end

    test "derive_season_from_date: nil → nil (defensive)" do
      assert_nil McpServer::Tools::BaseTool.derive_season_from_date(nil)
    end

    test "derive_season_from_date: Date-String wird akzeptiert (to_date-Polymorphismus)" do
      result = McpServer::Tools::BaseTool.derive_season_from_date("2025-08-15")
      skip "Season '2025/2026' nicht in Test-DB" if result.nil?
      assert_equal "2025/2026", result.name
    end

    # Plan 14-02.3 / F-2 Branch-Resolver: STI-Discipline mit type='Branch'.
    test "resolve_discipline_or_branch: blank → [nil, nil]" do
      ids, branch_name = McpServer::Tools::BaseTool.resolve_discipline_or_branch(nil)
      assert_nil ids
      assert_nil branch_name
      ids2, branch_name2 = McpServer::Tools::BaseTool.resolve_discipline_or_branch("")
      assert_nil ids2
      assert_nil branch_name2
    end

    test "resolve_discipline_or_branch: 'Pool' matched Branch → alle Pool-Sub-Disciplines" do
      ids, branch_name = McpServer::Tools::BaseTool.resolve_discipline_or_branch("Pool")
      pool_branch = Branch.find_by("name ILIKE ?", "Pool")
      skip "Branch 'Pool' nicht in Test-DB" if pool_branch.nil?
      expected_ids = Discipline.where(super_discipline_id: pool_branch.id).pluck(:id)
      skip "Keine Pool-Sub-Disciplines in Test-DB" if expected_ids.empty?
      assert_equal expected_ids.sort, ids.sort
      assert_equal pool_branch.name, branch_name
    end

    test "resolve_discipline_or_branch: '8-Ball' matched Discipline → [[id], nil]" do
      ids, branch_name = McpServer::Tools::BaseTool.resolve_discipline_or_branch("8-Ball")
      eight_ball = Discipline.find_by("name ILIKE ?", "8-Ball")
      skip "Discipline '8-Ball' nicht in Test-DB" if eight_ball.nil?
      assert_equal [eight_ball.id], ids
      assert_nil branch_name
    end

    test "resolve_discipline_or_branch: numerische ID-Fallback" do
      d = Discipline.first
      skip "Keine Discipline in Test-DB" if d.nil?
      ids, branch_name = McpServer::Tools::BaseTool.resolve_discipline_or_branch(d.id.to_s)
      assert_equal [d.id], ids
      assert_nil branch_name
    end

    test "resolve_discipline_or_branch: unbekanntes Token → [nil, nil]" do
      ids, branch_name = McpServer::Tools::BaseTool.resolve_discipline_or_branch("FrobnicateX9999")
      assert_nil ids
      assert_nil branch_name
    end
  end
end
