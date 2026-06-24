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
      # Beide Tokens müssen als ILIKE-Clauses im SQL erscheinen. Seit dem ß/Umlaut-Fix
      # (2026-06-16) sind die Spalten in replace(lower(...)) gewrappt und die Werte
      # normalisiert/lowercased (z.B. '%gernot%') — daher lower(col)…ILIKE…<token>.
      assert_match(/lower\(firstname\).*ILIKE.*gernot/i, sql)
      assert_match(/lower\(lastname\).*ILIKE.*gernot/i, sql)
      assert_match(/lower\(firstname\).*ILIKE.*ullrich/i, sql)
      assert_match(/lower\(lastname\).*ILIKE.*ullrich/i, sql)
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

    test "resolve_discipline_or_branch: 'Pool' matched Branch → rekursiv alle Pool-Sub-Disciplines" do
      ids, branch_name = McpServer::Tools::BaseTool.resolve_discipline_or_branch("Pool")
      pool_branch = Branch.find_by("name ILIKE ?", "Pool")
      skip "Branch 'Pool' nicht in Test-DB" if pool_branch.nil?
      expected_ids = McpServer::Tools::BaseTool.collect_subtree_ids(pool_branch.id)
      skip "Keine Pool-Sub-Disciplines in Test-DB" if expected_ids.empty?
      assert_equal expected_ids.sort, ids.sort
      assert_equal pool_branch.name, branch_name
    end

    test "resolve_discipline_or_branch: 'Karambol' matched Branch → enthält Blatt-Disziplinen (Cadre 35/2, Dreiband groß)" do
      ids, branch_name = McpServer::Tools::BaseTool.resolve_discipline_or_branch("Karambol")
      karambol_branch = Branch.find_by("name ILIKE ?", "Karambol")
      skip "Branch 'Karambol' nicht in Test-DB" if karambol_branch.nil?
      assert_equal karambol_branch.name, branch_name

      cadre_35_2 = Discipline.find_by(name: "Cadre 35/2")
      dreiband_gross = Discipline.find_by(name: "Dreiband groß")
      skip "Blatt-Disziplinen 'Cadre 35/2'/'Dreiband groß' nicht in Test-DB" if cadre_35_2.nil? && dreiband_gross.nil?

      assert_includes ids, cadre_35_2.id, "Cadre 35/2 (Ebene 2) muss im Branch-Resolver enthalten sein" if cadre_35_2
      assert_includes ids, dreiband_gross.id, "Dreiband groß (Ebene 2) muss im Branch-Resolver enthalten sein" if dreiband_gross
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

  # ---------------------------------------------------------------------------
  # Plan 14-G.12 Task 4 — resolve_club_cc_id Authority-Helper
  # ---------------------------------------------------------------------------
  # Sportwart-Wirkbereich-Resolver: aus user.sportwart_locations → clubs.cc_id;
  # mit Override-Validierung. Convention: [club_cc_id, error_response]-Tuple.
  class ResolveClubCcIdTest < ActiveSupport::TestCase
    setup do
      # Test-User mit Sportwart-Wirkbereich aus User.sportwart_locations
      @user = User.create!(
        email: "sportwart-test-#{SecureRandom.hex(4)}@example.com",
        password: "TestPassword1!",
        username: "sportwart_test_#{SecureRandom.hex(4)}",
        role: "club_admin"
      )

      # Region + Club + Location für Wirkbereich
      @region = Region.find_or_create_by!(shortname: "TEST") { |r| r.name = "Test Region" }
      @club = Club.create!(name: "BC Resolver-Test", shortname: "BCRT", cc_id: 999_001, region: @region)
      @location = Location.create!(name: "Test-Spielhalle")
      ClubLocation.create!(club: @club, location: @location)

      @user.sportwart_locations << @location

      @ctx = {user_id: @user.id, cc_region: "TEST"}
    end

    teardown do
      ClubLocation.where(location: @location).destroy_all
      @user.sportwart_location_assignments.destroy_all
      @location.destroy
      @club.destroy
      @user.destroy
    end

    test "resolve_club_cc_id: kein server_context → [nil, nil] (Caller-Decision)" do
      result, err = McpServer::Tools::BaseTool.resolve_club_cc_id(server_context: nil)
      assert_nil result
      assert_nil err
    end

    test "resolve_club_cc_id: server_context ohne user_id → [nil, nil]" do
      result, err = McpServer::Tools::BaseTool.resolve_club_cc_id(server_context: {cc_region: "TEST"})
      assert_nil result
      assert_nil err
    end

    test "resolve_club_cc_id: user_id stale (User nicht gefunden) → Error" do
      result, err = McpServer::Tools::BaseTool.resolve_club_cc_id(
        server_context: {user_id: 9_999_999}
      )
      assert_nil result
      assert err
      assert err.error?
      assert_match(/Token-Stale|nicht gefunden/, err.content.first[:text])
    end

    test "resolve_club_cc_id: N=1 Sportwart-Location → Auto-Resolve cc_id" do
      result, err = McpServer::Tools::BaseTool.resolve_club_cc_id(server_context: @ctx)
      assert_nil err
      assert_equal 999_001, result
    end

    test "resolve_club_cc_id: Override matching scope → OK" do
      result, err = McpServer::Tools::BaseTool.resolve_club_cc_id(
        server_context: @ctx, override: 999_001
      )
      assert_nil err
      assert_equal 999_001, result
    end

    test "resolve_club_cc_id: Override NICHT im scope → Authority-Denied" do
      result, err = McpServer::Tools::BaseTool.resolve_club_cc_id(
        server_context: @ctx, override: 888_888
      )
      assert_nil result
      assert err
      assert err.error?
      text = err.content.first[:text]
      assert_match(/Authority-Denied/, text)
      assert_match(/999001/, text)
      assert_match(/888888/, text)
    end

    test "resolve_club_cc_id: User ohne Sportwart-Wirkbereich → Error" do
      empty_user = User.create!(
        email: "empty-#{SecureRandom.hex(4)}@example.com",
        password: "TestPassword1!",
        username: "empty_#{SecureRandom.hex(4)}",
        role: "club_admin"
      )
      result, err = McpServer::Tools::BaseTool.resolve_club_cc_id(
        server_context: {user_id: empty_user.id}
      )
      assert_nil result
      assert err
      assert err.error?
      assert_match(/Kein Sportwart-Wirkbereich/, err.content.first[:text])
    ensure
      empty_user&.destroy
    end

    test "resolve_club_cc_id: N>1 Clubs → Disambig-Error" do
      # Zweiter Club + Location für Multi-Club-Sportwart
      club2 = Club.create!(name: "BC Resolver-Test-2", shortname: "BCRT2", cc_id: 999_002, region: @region)
      loc2 = Location.create!(name: "Test-Spielhalle-2")
      ClubLocation.create!(club: club2, location: loc2)
      @user.sportwart_locations << loc2

      result, err = McpServer::Tools::BaseTool.resolve_club_cc_id(server_context: @ctx)
      assert_nil result
      assert err
      assert err.error?
      text = err.content.first[:text]
      assert_match(/Mehrere Clubs/, text)
      assert_match(/999001/, text)
      assert_match(/999002/, text)
    ensure
      ClubLocation.where(location: loc2).destroy_all
      loc2&.destroy
      club2&.destroy
    end
  end

  # Plan 14-G.13.1 Task 1: Cache-Helper Tests.
  class CcCacheTest < ActiveSupport::TestCase
    teardown do
      McpServer::Tools::BaseTool.cc_cache_reset!
    end

    test "cc_cache_get_or_set returns cached value on second call with same key" do
      call_count = 0
      first = McpServer::Tools::BaseTool.cc_cache_get_or_set("k1") do
        call_count += 1
        "computed-value"
      end
      second = McpServer::Tools::BaseTool.cc_cache_get_or_set("k1") do
        call_count += 1
        "computed-value"
      end
      assert_equal "computed-value", first
      assert_equal "computed-value", second
      assert_equal 1, call_count, "Block should be yielded only once for same cache_key"
    end

    test "cc_cache_invalidate! clears entries by prefix" do
      McpServer::Tools::BaseTool.cc_cache_get_or_set("showCommittedMeldeliste:1310:abc") { "a" }
      McpServer::Tools::BaseTool.cc_cache_get_or_set("other:xyz") { "b" }
      McpServer::Tools::BaseTool.cc_cache_invalidate!(prefix: "showCommittedMeldeliste:")
      # showCommittedMeldeliste-Key wieder yielden → block läuft erneut.
      reset_called = false
      McpServer::Tools::BaseTool.cc_cache_get_or_set("showCommittedMeldeliste:1310:abc") do
        reset_called = true
        "fresh-a"
      end
      assert reset_called, "showCommittedMeldeliste-Key sollte nach Invalidate neu evaluiert werden"
      # other-Key bleibt cached → block läuft NICHT erneut.
      other_called = false
      McpServer::Tools::BaseTool.cc_cache_get_or_set("other:xyz") do
        other_called = true
        "fresh-b"
      end
      refute other_called, "other-Prefix-Key sollte erhalten bleiben"
    end

    test "cc_cache_reset! clears all entries" do
      McpServer::Tools::BaseTool.cc_cache_get_or_set("k1") { "v1" }
      McpServer::Tools::BaseTool.cc_cache_get_or_set("k2") { "v2" }
      McpServer::Tools::BaseTool.cc_cache_reset!
      assert_nil Thread.current[:cc_cache]
    end

    test "cc_cache_get_or_set transparent passthrough without prior reset" do
      McpServer::Tools::BaseTool.cc_cache_reset!
      val = McpServer::Tools::BaseTool.cc_cache_get_or_set("k1") { "v1" }
      assert_equal "v1", val
      assert_equal({"k1" => "v1"}, Thread.current[:cc_cache])
    end
  end

  # Plan 39-03 Task 1 (D-39-8/-9): Per-User-CC-Identitäts-Naht für die CC-Write-Tools.
  class CcIdentitySeamTest < ActiveSupport::TestCase
    CcAccount = McpServer::CcAccountResolver::CcAccount
    Seam = McpServer::Tools::BaseTool

    setup do
      @prev_mock = ENV["CARAMBUS_MCP_MOCK"]
      McpServer::CcSession.reset!
    end

    teardown do
      ENV["CARAMBUS_MCP_MOCK"] = @prev_mock
      McpServer::CcSession.reset!
    end

    def own_account(user_id: 1)
      CcAccount.new(login_username: "sw-eigen", password: "pw", source: :own, acting_user_id: user_id)
    end

    def none_account
      # Authentifizierter User OHNE eigene Creds (acting_user_id gesetzt) → Block greift.
      CcAccount.new(source: :none, acting_user_id: 7)
    end

    def none_account_stdio
      # User-loser Stdio-/Legacy-Pfad (acting_user_id nil) → kein Block (D-39-10).
      CcAccount.new(source: :none, acting_user_id: nil)
    end

    # --- resolve_cc_account (DB-Wiring um den Resolver) ---

    test "resolve_cc_account: User mit eigenen Creds → :own" do
      user = User.create!(email: "seam-own@test.de", password: "password123",
        cc_username: "seam-own-cc", cc_password: "seam-own-pw")
      acc = Seam.resolve_cc_account(tournament: nil, server_context: {user_id: user.id})
      assert_equal :own, acc.source
      assert acc.resolved?
      assert_equal "seam-own-cc", acc.login_username
      assert_equal user.id, acc.acting_user_id
    end

    test "resolve_cc_account: kein/unbekannter user_id → :none" do
      assert_equal :none, Seam.resolve_cc_account(tournament: nil, server_context: {}).source
      assert_equal :none, Seam.resolve_cc_account(tournament: nil, server_context: nil).source
      assert_equal :none, Seam.resolve_cc_account(tournament: nil, server_context: {user_id: 999_999_999}).source
    end

    # --- cc_write_identity_block (D-39-8: Block NUR bei armed:true + :none) ---

    test "cc_write_identity_block: aufgelöster Account → kein Block (armed egal)" do
      assert_nil Seam.cc_write_identity_block(own_account, armed: true)
      assert_nil Seam.cc_write_identity_block(own_account, armed: false)
    end

    test "cc_write_identity_block: :none + armed:true → Block mit jargonfreier Meldung" do
      resp = Seam.cc_write_identity_block(none_account, armed: true)
      refute_nil resp
      assert resp.error?
      text = resp.content.map { |c| c[:text] }.join
      assert_equal Seam::CC_IDENTITY_REQUIRED_MSG, text
      refute_match(/Token|Session|Cache|Credential/i, text, "keine IT-Jargon-Begriffe (MCP-Language-Direktive)")
    end

    test "cc_write_identity_block: :none + Dry-Run (armed:false) → KEIN Block" do
      assert_nil Seam.cc_write_identity_block(none_account, armed: false)
    end

    test "cc_write_identity_block: Stdio-Pfad (:none ohne acting_user_id) + armed:true → KEIN Block (D-39-10)" do
      assert_nil Seam.cc_write_identity_block(none_account_stdio, armed: true),
        "User-loser Stdio-/Legacy-Pfad behält die geteilte Admin-Session (D-13-01-F)"
    end

    # --- cc_identity_hint (nicht-blockierender Dry-Run-Hinweis) ---

    test "cc_identity_hint: authentifizierter :none → Hinweis; aufgelöst/Stdio → nil" do
      assert_equal Seam::CC_IDENTITY_REQUIRED_MSG, Seam.cc_identity_hint(none_account)
      assert_nil Seam.cc_identity_hint(own_account)
      assert_nil Seam.cc_identity_hint(none_account_stdio), "Stdio-Pfad ohne User → kein Hinweis (D-39-10)"
    end

    # --- cc_audit_operator (CC-Login-Account des aktiven Slots) ---

    test "cc_audit_operator: ohne aktive Session → 'unknown'" do
      assert_equal "unknown", Seam.cc_audit_operator
    end

    test "cc_audit_operator: nach per-Account-Login → dessen CC-Login-Name" do
      ENV["CARAMBUS_MCP_MOCK"] = "1"
      McpServer::CcSession.cookie_for(own_account)  # mock-Login setzt aktiven Account = login_username
      assert_equal "sw-eigen", Seam.cc_audit_operator
    end

    # Zweischichtige Attribution (D-39-2): operator = CC-Login des Granters, user_id = echter TL.
    test "tl_inherited: operator = Granter-CC-Login, user_id-Quelle = echter TL" do
      ENV["CARAMBUS_MCP_MOCK"] = "1"
      tl_acc = CcAccount.new(login_username: "sw-granter", password: "pw",
        source: :tl_inherited, acting_user_id: 99, granted_by_user_id: 5)
      assert tl_acc.resolved?
      assert_nil Seam.cc_write_identity_block(tl_acc, armed: true), "tl_inherited darf nicht blocken"
      McpServer::CcSession.cookie_for(tl_acc)
      assert_equal "sw-granter", Seam.cc_audit_operator, "operator = CC-Login des einsetzenden Sportwarts"
      assert_equal 99, tl_acc.acting_user_id, "user_id-Quelle = echter Turnierleiter"
    end
  end

  # Plan 46-01: resolve_party (Region-Scope) + party_preparation_authorized? (Persona-Backbone).
  class ResolvePartyAndAuthorityTest < ActiveSupport::TestCase
    Seam = McpServer::Tools::BaseTool

    setup do
      @nbv = regions(:nbv)
      @season = seasons(:current)
      @pool = Branch.create!(name: "Pool")
      @league = League.create!(name: "P4601B Pool Liga", shortname: "P4601B-PL",
        organizer: @nbv, season: @season, discipline: @pool, cc_id: 946_011)
      @a = LeagueTeam.create!(league: @league, name: "P4601B A")
      @b = LeagueTeam.create!(league: @league, name: "P4601B B")
      @party = Party.create!(league: @league, league_team_a: @a, league_team_b: @b,
        host_league_team: @a, day_seqno: 1, date: Date.new(2026, 3, 20), data: {})
      @ctx = {cc_region: "NBV"}
    end

    test "resolve_party: party_id-Pfad (region-scoped)" do
      r = Seam.resolve_party(@ctx, party_id: @party.id)
      assert_nil r[:error], "got: #{r[:error]&.content&.first&.dig(:text)}"
      assert_equal @party.id, r[:party].id
    end

    test "resolve_party: league_id + day_seqno-Pfad findet dieselbe Party" do
      r = Seam.resolve_party(@ctx, league_id: @league.id, day_seqno: 1)
      assert_nil r[:error]
      assert_equal @party.id, r[:party].id
    end

    test "resolve_party: Cross-Region → error (kein Leak)" do
      skip "fixture bbv fehlt" unless regions(:bbv)
      ol = League.create!(name: "P4601B BBV", shortname: "P4601B-BBV",
        organizer: regions(:bbv), season: @season, discipline: @pool, cc_id: 946_012)
      oa = LeagueTeam.create!(league: ol, name: "P4601B BBV A")
      ob = LeagueTeam.create!(league: ol, name: "P4601B BBV B")
      op = Party.create!(league: ol, league_team_a: oa, league_team_b: ob,
        host_league_team: oa, day_seqno: 1, date: Date.new(2026, 3, 20), data: {})
      r = Seam.resolve_party(@ctx, party_id: op.id)
      assert r[:error], "Cross-Region muss error liefern"
    end

    test "authority: system_admin → erlaubt" do
      assert Seam.party_preparation_authorized?(party: @party, server_context: {user_id: users(:system_admin).id})
    end

    test "authority: read-only player → verweigert" do
      refute Seam.party_preparation_authorized?(party: @party, server_context: {user_id: users(:player).id})
    end

    test "authority: landessportwart → erlaubt (region-weit)" do
      lsw = User.create!(email: "p4601b_lsw@test.de", password: "password123", persona_grants: ["landessportwart"])
      assert Seam.party_preparation_authorized?(party: @party, server_context: {user_id: lsw.id})
    end

    test "authority: Sportwart mit passender Disziplin → erlaubt; mit fremder Disziplin → verweigert" do
      sw_pool = User.create!(email: "p4601b_swp@test.de", password: "password123", persona_grants: ["sportwart"])
      sw_pool.sportwart_disciplines << @pool
      assert Seam.party_preparation_authorized?(party: @party, server_context: {user_id: sw_pool.id})

      karambol = Branch.create!(name: "Karambol P4601B")
      sw_kar = User.create!(email: "p4601b_swk@test.de", password: "password123", persona_grants: ["sportwart"])
      sw_kar.sportwart_disciplines << karambol
      refute Seam.party_preparation_authorized?(party: @party, server_context: {user_id: sw_kar.id})
    end

    test "authorize_party_preparation!: nil bei Erlaubnis, error bei Denial" do
      assert_nil Seam.authorize_party_preparation!(party: @party, server_context: {user_id: users(:system_admin).id})
      denied = Seam.authorize_party_preparation!(party: @party, server_context: {user_id: users(:player).id})
      assert denied.error?
      assert_match(/nicht zuständig/i, denied.content.first[:text])
    end
  end
end
