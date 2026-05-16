# frozen_string_literal: true

require "test_helper"

# Tests für cc_register_for_tournament (Plan 04-04 Live-Implementation).
# Mock-only Scope: keine Live-CC-Calls; Live-Validation ist Plan 04-04 Task 6 (User-Action).
#
# Sicherheitsschichten-Coverage:
#   1. armed-Default false → Test 1 (dry-run)
#   2. Mock-Mode-Default → setup nutzt _client_override mit MockClient
#   3. Rails-env-Check → Test 8 (Rails.env.production? blockiert armed:true)
#   4. Detail-Dry-Run-Echo → Test 1 (alle ID-Werte im Output)
#
# 2-Step-Workflow-Coverage (Plan 04-04, aus SNIFF v2):
#   Test 2: armed:true ruft 3 sequentielle Calls in Reihenfolge
#     (addPlayerToMeldeliste → saveMeldeliste → showCommittedMeldeliste)
#   Test 3: verified_in_committed_list:true bei Player-Marker im verify-Response-Body
#
# Konsistenz-Check Option A (Existenz auf PlayerRanking) → Test 7.
class McpServer::Tools::RegisterForTournamentTest < ActiveSupport::TestCase
  setup do
    # Pattern aus finalize_teilnehmerliste_test.rb:8-15 — _client_override umgeht Real-Login.
    McpServer::CcSession.reset!
    McpServer::CcSession.session_id = "TEST_SESSION_ID"
    McpServer::CcSession.session_started_at = Time.now
    @mock = McpServer::Tools::MockClient.new
    McpServer::CcSession._client_override = @mock
  end

  teardown do
    McpServer::CcSession._client_override = nil
    McpServer::CcSession.reset!
  end

  test "armed:false (default) returns 'Would register' text mit allen ID-Werten ohne CC-Mutation" do
    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 99999, club_cc_id: 1010,
      server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    # Schicht 4: alle ID-Werte explizit im Dry-Run-Output (Plan 14-G.13 Multi-Player-Format)
    assert_match(/\[DRY-RUN\] Would register 1 player\(s\) \[99999\]/, text)
    assert_match(/meldeliste_cc_id=1310/, text)
    assert_match(/fed_id=20/, text)
    assert_match(/branch_cc_id=8/, text)
    assert_match(/club_cc_id=1010/, text)
    assert_match(/season=2025\/2026/, text)
    assert_match(/Workflow: Multi-Add-Loop/, text)
    assert_match(/Pass armed:true to actually perform/, text)
    # Schicht 1: armed=false erreicht client.post NIE
    assert @mock.calls.empty?, "Dry-run darf MockClient nicht aufrufen, aber #{@mock.calls.inspect}"
  end

  test "armed:true Mock-Success ruft 3 sequentielle POSTs (cc_add → save → verify) in genau dieser Reihenfolge" do
    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 99999, club_cc_id: 1010,
      armed: true, server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    # Plan 14-G.13: Multi-Player-Output-Format auch für single-Player-Input.
    assert_match(/Registered 0\/1 player\(s\) into meldeliste_cc_id=1310/, text)
    assert_match(/player_cc_ids: \[99999\]/, text)
    # 2-Step-Workflow + Verifikation: exakt 3 POSTs in dieser Reihenfolge (single-player Backwards-Compat)
    posts = @mock.calls.select { |verb, _, _, opts| verb == :post && opts[:armed] }
    actions = posts.map { |_, action, _, _| action }
    assert_equal %w[addPlayerToMeldeliste saveMeldeliste showCommittedMeldeliste], actions,
      "Erwarte 3 POSTs in genau dieser Reihenfolge — got #{actions.inspect}"
    # Default-MockClient liefert body="" → verified=false (kein Marker im Mock-HTML)
    assert_match(/verified_in_committed_list: false/, text)
  end

  test "Phase-5-D3-Bugfix: showCommittedMeldeliste-Payload hat 8 Felder ohne firstEntry/rang/selectedClubId" do
    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 99999, club_cc_id: 1010,
      armed: true, server_context: nil
    )
    refute response.error?
    verify_call = @mock.calls.find { |verb, action, _, _| verb == :post && action == "showCommittedMeldeliste" }
    assert verify_call, "showCommittedMeldeliste muss aufgerufen worden sein"
    _, _, params, _ = verify_call
    expected_keys = %i[clubId fedId branchId disciplinId catId season meldelisteId sortOrder].sort
    assert_equal expected_keys, params.keys.sort,
      "Verify-Payload muss genau 8 Felder haben (D3-Bugfix); got #{params.keys.sort.inspect}"
    refute params.key?(:firstEntry), "firstEntry darf NICHT im show-Payload sein (add/save-spezifisch)"
    refute params.key?(:rang), "rang darf NICHT im show-Payload sein (add/save-spezifisch)"
    refute params.key?(:selectedClubId), "selectedClubId darf NICHT im show-Payload sein (add/save-spezifisch)"
  end

  test "Plan 11-04 T1-Fix: showCommittedMeldeliste-Payload nutzt clubId='*' (Multi-Club-Meldeliste-Compat)" do
    # Plan 11-03 RESEARCH.md H1 HIGH-Likelihood: clubId=club_cc_id im Verify-Payload würde
    # CC PHP-Code als Server-side-Filter interpretieren → Player aus anderem Club erscheint
    # NICHT in der gefilterten Show-Response trotz erfolgreichem Save. Fix: clubId="*"
    # (Wildcard) analog cc_lookup_tournament's read_committed_players-Helper (Zeile 203).
    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 99999, club_cc_id: 1010,
      armed: true, server_context: nil
    )
    refute response.error?
    verify_call = @mock.calls.find { |verb, action, _, _| verb == :post && action == "showCommittedMeldeliste" }
    assert verify_call, "showCommittedMeldeliste muss aufgerufen worden sein"
    _, _, params, _ = verify_call
    assert_equal "*", params[:clubId],
      "Verify-Payload clubId muss '*' (Wildcard) sein, NICHT club_cc_id=1010 (Plan 11-04 T1-Fix); got: #{params[:clubId].inspect}"
  end

  test "armed:true mit Player-Marker im verify-Response-Body → verified_in_committed_list:true" do
    # Override post() um showCommittedMeldeliste-Response mit Player-cc_id-Markup zu liefern.
    @mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      if action == "showCommittedMeldeliste"
        body = %(<html><body><table><tr><td align="center">99999</td></tr></table></body></html>)
        [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
      else
        [Struct.new(:code, :message, :body).new("200", "OK", ""), Nokogiri::HTML("<html></html>")]
      end
    end

    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 99999, club_cc_id: 1010,
      armed: true, server_context: nil
    )
    refute response.error?
    assert_match(/verified_in_committed_list: true/, response.content.first[:text])
  end

  test "Validation: fehlendes player_cc_id gibt error mit Parameter-Namen zurück" do
    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, club_cc_id: 1010,
      server_context: nil
    )
    assert response.error?
    # Plan 14-G.13: exactly-one-rule kommt jetzt vor validate_required! → spezifischere Diagnose.
    assert_match(/missing player input/i, response.content.first[:text])
    assert_match(/player_cc_id/, response.content.first[:text])
  end

  test "Permission-Error: error-div in cc_add-Response wird als MCP-Error zurückgegeben" do
    error_doc = Nokogiri::HTML('<html><body><div class="error">Permission denied: club role required</div></body></html>')
    @mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      [Struct.new(:code, :message, :body).new("200", "OK", ""), error_doc]
    end

    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 99999, club_cc_id: 1010,
      armed: true, server_context: nil
    )
    assert response.error?
    assert_match(/CC rejected at cc_add.*Permission denied/, response.content.first[:text])
  end

  test "Defensive: Exception in client.post gibt error envelope ohne stacktrace zurück" do
    @mock.define_singleton_method(:post) do |*_|
      raise "simulated network failure"
    end

    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 99999, club_cc_id: 1010,
      armed: true, server_context: nil
    )
    assert response.error?
    assert_match(/Tool exception: RuntimeError/, response.content.first[:text])
    refute_match(/backtrace|line \d+/i, response.content.first[:text])
  end

  test "Konsistenz-Check: Player nicht in Carambus-DB erzeugt 'übersprungen'-Status im Output" do
    # cc_id=99999999 ist garantiert nicht in DB → Player.find_by liefert nil
    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 99999999, club_cc_id: 1010,
      server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    # Konsistenz-Check Option A: Player nicht in DB → "übersprungen"-Status
    assert_match(/Konsistenz-Check übersprungen.*nicht in Carambus-DB/, text)
  end

  # Plan 10-05.1 Task 1 (D-10-04-B Pivot): Phase-4-Schicht-3 (Production-Block) DEPRECATED.
  # Der vorherige Test "Schicht 3: armed:true in Rails production env wird mit error blockiert"
  # wurde entfernt. Pre-Validation-First-Pattern (Task 2) ersetzt globalen env-Block durch
  # Tool-eigene Constraints — Sportwart/Turnierleiter können armed:true in Live-Production ausführen,
  # weil das Tool selbst zum Sicherheitsnetz wird via _validate_*-Methoden.

  # --- Plan 10-05.1 Task 2: Pre-Validation-First-Pattern (7 Constraints, D-10-04-G) ---

  test "Pre-Validation: 7 Constraints werden alle aufgerufen + im Output reported" do
    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 99999, club_cc_id: 1010,
      armed: true, server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    # pre_validation_passed-Status im Output sichtbar
    assert_match(/pre_validation_passed: true/, text)
  end

  test "_validate_scope_konsistent: fed_id required" do
    result = McpServer::Tools::RegisterForTournament.send(:_validate_scope_konsistent, 1310, nil, 8, "2025/2026")
    assert_equal false, result[:ok]
    assert_match(/fed_id missing/, result[:reason])
  end

  test "_validate_scope_konsistent: branch_cc_id required" do
    result = McpServer::Tools::RegisterForTournament.send(:_validate_scope_konsistent, 1310, 20, nil, "2025/2026")
    assert_equal false, result[:ok]
    assert_match(/branch_cc_id missing/, result[:reason])
  end

  test "_validate_scope_konsistent: season required" do
    result = McpServer::Tools::RegisterForTournament.send(:_validate_scope_konsistent, 1310, 20, 8, nil)
    assert_equal false, result[:ok]
    assert_match(/season missing/, result[:reason])
  end

  test "_validate_scope_konsistent: alle Params präsent → ok:true" do
    result = McpServer::Tools::RegisterForTournament.send(:_validate_scope_konsistent, 1310, 20, 8, "2025/2026")
    assert_equal true, result[:ok]
  end

  test "_validate_player_exists: missing player_cc_id → reject" do
    result = McpServer::Tools::RegisterForTournament.send(:_validate_player_exists, nil)
    # Helper: nil player_cc_id → reject mit Hinweis
    assert_equal false, result[:ok]
    assert_match(/player_cc_id missing/, result[:reason])
  end

  test "_validate_meldeliste_exists: missing meldeliste_cc_id → reject" do
    result = McpServer::Tools::RegisterForTournament.send(:_validate_meldeliste_exists, nil)
    assert_equal false, result[:ok]
    assert_match(/meldeliste_cc_id missing/, result[:reason])
  end

  test "_validate_club_cross_check: missing club_cc_id → defensive ok:true" do
    result = McpServer::Tools::RegisterForTournament.send(:_validate_club_cross_check, 99999, nil)
    assert_equal true, result[:ok]
  end

  # --- Plan 14-G.13 (Quick 260516-x7g) Multi-Player-Save-Fix: Tests M1-M8 ---
  #
  # Bug: sequenzielle N×(add+save) verlieren Buffer-Adds — jeder save flusht den Edit-Buffer
  # und überschreibt die vorherigen Adds. Fix: N×addPlayerToMeldeliste + 1×saveMeldeliste
  # am Ende + 1×showCommittedMeldeliste verify. Pattern aus cc_assign_player_to_teilnehmerliste.

  test "M1: armed:false mit player_cc_ids:[10024, 11683] zeigt DRY-RUN für BEIDE Player" do
    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_ids: [10024, 11683], club_cc_id: 1010,
      server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    assert_match(/\[DRY-RUN\] Would register 2 player\(s\)/, text)
    assert_match(/10024/, text)
    assert_match(/11683/, text)
    assert_match(/Multi-Add-Loop/, text)
    assert @mock.calls.empty?, "Dry-run darf MockClient nicht aufrufen, aber #{@mock.calls.inspect}"
  end

  test "M2: armed:true mit player_cc_ids:[10024, 11683] ruft N×add + 1×save + 1×verify" do
    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_ids: [10024, 11683], club_cc_id: 1010,
      armed: true, server_context: nil
    )
    refute response.error?
    posts = @mock.calls.select { |verb, _, _, opts| verb == :post && opts[:armed] }
    actions = posts.map { |_, action, _, _| action }
    # Erwartete Sequenz: 2× addPlayerToMeldeliste + 1× saveMeldeliste + 1× showCommittedMeldeliste
    expected_actions = %w[addPlayerToMeldeliste addPlayerToMeldeliste saveMeldeliste showCommittedMeldeliste]
    assert_equal expected_actions, actions,
      "Erwarte 2-Player-Add-Loop + 1×save + 1×verify — got #{actions.inspect}"
    # Verify die zwei adds mit den richtigen player_cc_ids
    add_calls = posts.select { |_, action, _, _| action == "addPlayerToMeldeliste" }
    add_player_ids = add_calls.map { |_, _, params, _| params[:a] }
    assert_equal [10024, 11683], add_player_ids,
      "Add-Loop muss player_cc_ids in der gegebenen Reihenfolge senden"
  end

  test "M3: armed:true verify-Response enthält BEIDE Marker → verified_in_committed_list:true" do
    @mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      if action == "showCommittedMeldeliste"
        body = %(<html><body><table><tr><td align="center">10024</td></tr><tr><td align="center">11683</td></tr></table></body></html>)
        [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
      else
        [Struct.new(:code, :message, :body).new("200", "OK", ""), Nokogiri::HTML("<html></html>")]
      end
    end

    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_ids: [10024, 11683], club_cc_id: 1010,
      armed: true, server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    assert_match(/verified_in_committed_list: true/, text)
    assert_match(/verified_player_cc_ids: \[10024, 11683\]/, text)
    assert_match(/missing_player_cc_ids:  \[\]/, text)
  end

  test "M4: armed:true partial-verify (nur 10024, nicht 11683) → verified=false + missing=[11683]" do
    @mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      if action == "showCommittedMeldeliste"
        body = %(<html><body><table><tr><td align="center">10024</td></tr></table></body></html>)
        [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
      else
        [Struct.new(:code, :message, :body).new("200", "OK", ""), Nokogiri::HTML("<html></html>")]
      end
    end

    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_ids: [10024, 11683], club_cc_id: 1010,
      armed: true, server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    assert_match(/verified_in_committed_list: false/, text)
    assert_match(/verified_player_cc_ids: \[10024\]/, text)
    assert_match(/missing_player_cc_ids:  \[11683\]/, text)
  end

  test "M5 Backwards-Compat: player_cc_id:10024 (singular) ruft genau 3 POSTs (1×add+1×save+1×verify)" do
    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 10024, club_cc_id: 1010,
      armed: true, server_context: nil
    )
    refute response.error?
    posts = @mock.calls.select { |verb, _, _, opts| verb == :post && opts[:armed] }
    actions = posts.map { |_, action, _, _| action }
    # Single-Player muss identisch zu vorher 3 POSTs ergeben (Backwards-Compat-HARD-Constraint)
    assert_equal %w[addPlayerToMeldeliste saveMeldeliste showCommittedMeldeliste], actions,
      "Single-Player-Pfad muss byte-identisch zur Pre-Bug-Variante bleiben — got #{actions.inspect}"
  end

  test "M6: weder player_cc_id noch player_cc_ids gesetzt → klare Diagnose-Message" do
    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, club_cc_id: 1010,
      server_context: nil
    )
    assert response.error?
    assert_match(/missing player input/i, response.content.first[:text])
  end

  test "M7: BEIDE player_cc_id UND player_cc_ids gesetzt → exactly-one-rule error" do
    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 10024, player_cc_ids: [11683, 10031], club_cc_id: 1010,
      server_context: nil
    )
    assert response.error?
    assert_match(/exactly one of player_cc_id/, response.content.first[:text])
  end

  test "M8: Pre-Validation-Fail eines Players blockiert ALLE (atomare Semantik)" do
    # Stubbe _validate_player_not_doppelt um pid=11683 zu rejecten, andere zu akzeptieren.
    McpServer::Tools::RegisterForTournament.singleton_class.send(:alias_method, :_orig_validate_player_not_doppelt_m8, :_validate_player_not_doppelt)
    McpServer::Tools::RegisterForTournament.define_singleton_method(:_validate_player_not_doppelt) do |pid, *args|
      if pid == 11683
        {name: "player_not_doppelt", ok: false, reason: "[player_cc_id=#{pid}] Player bereits in Meldeliste"}
      else
        {name: "player_not_doppelt", ok: true}
      end
    end

    begin
      response = McpServer::Tools::RegisterForTournament.call(
        fed_id: 20, branch_cc_id: 8, season: "2025/2026",
        meldeliste_cc_id: 1310, player_cc_ids: [10024, 11683, 10031], club_cc_id: 1010,
        armed: true, server_context: nil
      )
      assert response.error?
      text = response.content.first[:text]
      assert_match(/Pre-Validation failed/, text)
      # Diagnose muss zeigen, welcher Player den Fail verursachte (11683)
      assert_match(/11683/, text)
      # KEIN Mock-Call darf abgesetzt worden sein (atomare Semantik — alle abgelehnt)
      posts = @mock.calls.select { |verb, _, _, opts| verb == :post && opts[:armed] }
      assert posts.empty?, "Bei Pre-Validation-Fail darf KEIN armed-POST abgesetzt werden — got #{posts.inspect}"
    ensure
      McpServer::Tools::RegisterForTournament.singleton_class.send(:alias_method, :_validate_player_not_doppelt, :_orig_validate_player_not_doppelt_m8)
      McpServer::Tools::RegisterForTournament.singleton_class.send(:remove_method, :_orig_validate_player_not_doppelt_m8)
    end
  end
end
