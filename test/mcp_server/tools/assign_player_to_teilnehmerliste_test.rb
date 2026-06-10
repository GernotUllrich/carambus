# frozen_string_literal: true

require "test_helper"

# Tests für cc_assign_player_to_teilnehmerliste (Plan 07-03 Mock-Implementation).
# Mock-only Scope: keine Live-CC-Calls; Live-Validation ist Plan 07-04 (User-Action).
#
# Sicherheitsschichten-Coverage:
#   1. armed-Default false → Test 1 (dry-run mit Detail-Echo)
#   2. Mock-Mode-Default → setup nutzt _client_override mit MockClient (NICHT CARAMBUS_MCP_MOCK=1!)
#   3. Rails-env-Check → Test 7 (production? blockiert armed:true)
#   4. Detail-Dry-Run-Echo → Test 1 (Tournament-Name, Player-Liste, Counts)
#
# Multi-Step-Workflow-Coverage (aus 07-02 SNIFF-OUTPUT.md):
#   Test 2: armed:true Single-Add → editTeilnehmerlisteCheck → assignPlayer → editTeilnehmerlisteSave → Read-Back
#   Test 3: armed:true Multi-Add → meldungId[] Array mit ≥2 cc_ids in EINEM Call
#   Test 4: Save-Sentinel save="1" non-blank
#
# Pre-Validation:
#   Test 5: player nicht in Meldeliste-Available → ToolError mit cc_register_for_tournament-Hinweis
#   Test 6: player bereits in Teilnehmerliste → ToolError mit Duplicate-Liste
#
# NBV-only-Constraint + Real-CC-Format → Tests 8 + 10.

class McpServer::Tools::AssignPlayerToTeilnehmerlisteTest < ActiveSupport::TestCase
  # Build editTeilnehmerlisteCheck-Response-HTML analog 07-02 Captures.
  # Mock-Format: <select name="teilnehmerId"> + <select name="meldungId[]"> + Tournament-Name.
  def self.build_check_html(teilnehmer_options: [], meldung_options: [], tournament_name: "MOCK NDM Endrunde Eurokegel")
    teilnehmer_html = teilnehmer_options.map { |cc_id, label| %(<option value="#{cc_id}">#{label}</option>) }.join
    teilnehmer_html = %(<option value=""></option>) if teilnehmer_options.empty?
    meldung_html = meldung_options.map { |cc_id, label| %(<option value="#{cc_id}">#{label}</option>) }.join
    meldung_html = %(<option value=""></option>) if meldung_options.empty?
    <<~HTML
      <html><body>
      <form name="billard" method="post">
      <input type="hidden" name="fedId" value="20">
      <input type="hidden" name="branchId" value="8">
      <input type="hidden" name="disciplinId" value="*">
      <input type="hidden" name="season" value="2025/2026">
      <input type="hidden" name="catId" value="*">
      <input type="hidden" name="meisterTypeId" value="">
      <input type="hidden" name="meisterschaftsId" value="890">
      <input type="hidden" name="sortedBy" value="playername">
      <input type="hidden" name="firstEntry" value="1">
      <table>
        <tr><td>Meisterschaft</td><td>&nbsp;</td><td class="white" nowrap><b>#{tournament_name}</b></td></tr>
      </table>
      <select name="teilnehmerId">#{teilnehmer_html}</select>
      <select name="meldungId[]" multiple>#{meldung_html}</select>
      </form>
      </body></html>
    HTML
  end

  setup do
    McpServer::CcSession.reset!
    McpServer::CcSession.session_id = "TEST_SESSION_ID"
    McpServer::CcSession.session_started_at = Time.now
    @mock = build_stateful_mock
    McpServer::CcSession._client_override = @mock
  end

  teardown do
    McpServer::CcSession._client_override = nil
    McpServer::CcSession.reset!
  end

  # Stateful MockClient: simuliert assignPlayer-State-Mutation.
  # Pre-Read und Read-Back liefern unterschiedliche <select>-Optionen je nach State.
  # Initial: Meldeliste hat 11683 + 10024; Teilnehmerliste leer.
  # Nach assignPlayer: Spieler wechseln von Meldeliste → Teilnehmerliste.
  def build_stateful_mock(initial_meldung: [[11683, "Nachtmann, Georg (11683)"], [10024, "Schröder, Hans-Jörg (10024)"]],
    initial_teilnehmer: [], tournament_name: "MOCK NDM Endrunde Eurokegel")
    current_teilnehmer = initial_teilnehmer.dup
    current_meldung = initial_meldung.dup
    helper = self.class
    mock = McpServer::Tools::MockClient.new
    mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      case action
      when "editTeilnehmerlisteCheck"
        body = helper.build_check_html(
          teilnehmer_options: current_teilnehmer,
          meldung_options: current_meldung,
          tournament_name: tournament_name
        )
        [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
      when "showMeldeliste_teilnahme"
        # Plan 33-fix: atomarer Akkreditierungs-Toggle. State-Mutation: pid von meldung → teilnehmer.
        cc_id = params[:pid].to_i
        moved = current_meldung.find { |id, _| id == cc_id }
        if moved
          current_teilnehmer << moved
          # Hinweis: CC lässt akkreditierte Spieler in der Meldeliste sichtbar; fürs Mock-Modell
          # genügt die Teilnehmer-Aufnahme, damit der Read-Back den Spieler findet.
        end
        [Struct.new(:code, :message, :body).new("200", "OK", ""),
          Nokogiri::HTML("<html><body>MOCK POST showMeldeliste_teilnahme OK</body></html>")]
      else
        [Struct.new(:code, :message, :body).new("200", "OK", ""),
          Nokogiri::HTML("<html><body>MOCK POST #{action} OK</body></html>")]
      end
    end
    mock
  end

  # --- AC-1 (Schicht 1+3+4 + Validation) ---

  test "armed:false (default) returns Detail-Echo with Tournament-Name + Player-List + Counts ohne Save" do
    response = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_ids: [11683],
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      server_context: nil
    )
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    text = response.content.first[:text]
    # Schicht 4: Detail-Echo
    assert_match(/\[DRY-RUN\] Would assign 1 player.*tournament_cc_id=890/, text)
    assert_match(/MOCK NDM Endrunde Eurokegel/, text)
    assert_match(/11683.*Nachtmann/, text)
    assert_match(/teilnehmerliste_count_before: 0/, text)
    assert_match(/teilnehmerliste_count_after:  1/, text)
    assert_match(/available_in_meldeliste:.*2 player/, text)
    assert_match(/Workflow: showMeldeliste_teilnahme.*Toggle/, text)
    # Schicht 1: armed=false darf NIEMALS den Akkreditierungs-Toggle aufrufen
    write_calls = @mock.calls.select { |verb, action, _, _| verb == :post && %w[showMeldeliste_teilnahme assignPlayer editTeilnehmerlisteSave].include?(action) }
    assert write_calls.empty?, "Dry-Run darf showMeldeliste_teilnahme NICHT aufrufen — got #{write_calls.inspect}"
    # Pre-Read editTeilnehmerlisteCheck DARF aufgerufen werden
    pre_reads = @mock.calls.select { |verb, action, _, _| verb == :post && action == "editTeilnehmerlisteCheck" }
    assert_equal 1, pre_reads.size, "Dry-Run macht exakt 1 Pre-Read — got #{pre_reads.size}"
  end

  test "armed:true Single-Add ruft Pre-Read → showMeldeliste_teilnahme → Read-Back in genau dieser Reihenfolge" do
    response = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_ids: [11683],
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      armed: true, server_context: nil
    )
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    text = response.content.first[:text]
    assert_match(/Assigned 1 player.*tournament_cc_id=890.*MOCK NDM Endrunde/, text)
    assert_match(/added: \[11683\]/, text)
    assert_match(/read_back_match: true/, text)
    # Plan 33-fix: Pre-Read → showMeldeliste_teilnahme (atomarer Toggle) → Read-Back.
    # Kein assignPlayer/Re-Render/Save mehr (Edit-Buffer-Race eliminiert).
    actions = @mock.calls.select { |verb, _, _, _| verb == :post }.map { |_, a, _, _| a }
    assert_equal ["editTeilnehmerlisteCheck", "showMeldeliste_teilnahme", "editTeilnehmerlisteCheck"], actions,
      "Erwarte Pre-Read → Toggle → Read-Back — got #{actions.inspect}"
  end

  # --- AC-2 Multi-Add (Phase-7-Spezifikum) ---

  test "Multi-Add: player_cc_ids=[11683, 10024] erzeugt EINEN showMeldeliste_teilnahme-Toggle pro Spieler" do
    response = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_ids: [11683, 10024],
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      armed: true, server_context: nil
    )
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    assert_match(/Assigned 2 player/, response.content.first[:text])
    # Plan 33-fix: EIN atomarer Toggle pro Spieler (kein Multi-Add via meldungId[]).
    toggle_calls = @mock.calls.select { |verb, action, _, _| verb == :post && action == "showMeldeliste_teilnahme" }
    assert_equal 2, toggle_calls.size, "Multi-Add macht 1 Toggle pro Spieler — got #{toggle_calls.size}"
    toggled_pids = toggle_calls.map { |_, _, params, _| params[:pid] }
    assert_equal [11683, 10024], toggled_pids, "Je ein pid-Toggle in Reihenfolge — got #{toggled_pids.inspect}"
    # Verify count_after im Final-Text
    assert_match(/teilnehmerliste_count_after:  2/, response.content.first[:text])
  end

  test "Toggle-Payload enthält Base-Felder (ohne firstEntry/save) + pid (HAR-Goldvorlage)" do
    McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_ids: [11683],
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      armed: true, server_context: nil
    )
    toggle_call = @mock.calls.find { |verb, action, _, _| verb == :post && action == "showMeldeliste_teilnahme" }
    refute_nil toggle_call, "showMeldeliste_teilnahme muss aufgerufen worden sein"
    _, _, params, _ = toggle_call
    # Plan 33-fix: Toggle-Payload aus tmp/Schnellanmeldung.har:
    #   fedId, branchId, disciplinId, season, catId, meisterTypeId, meisterschaftsId, sortedBy, pid
    required_keys = %i[fedId branchId disciplinId catId season meisterTypeId meisterschaftsId sortedBy pid]
    missing_keys = required_keys - params.keys
    assert_empty missing_keys, "Toggle-Payload fehlen Felder: #{missing_keys.inspect}; got #{params.keys.sort.inspect}"
    refute params.key?(:firstEntry), "firstEntry darf NICHT im Toggle-Payload sein (HAR-belegt)"
    refute params.key?(:save), "save darf NICHT im Toggle-Payload sein (kein Save-Step mehr)"
    assert_equal 11683, params[:pid], "pid = player_cc_id (atomarer Toggle)"
    assert_equal 890, params[:meisterschaftsId], "meisterschaftsId = tournament_cc_id (Phase-7-Identifier)"
  end

  # --- AC-1 Pre-Validation ---

  test "Validation: player nicht in Meldeliste-Available → ToolError mit cc_register_for_tournament-Hinweis" do
    response = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_ids: [99999], # NICHT in Meldeliste
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      armed: true, server_context: nil
    )
    assert response.error?
    text = response.content.first[:text]
    assert_match(/not in Meldeliste-Available.*99999/, text)
    assert_match(/cc_register_for_tournament/, text)
    # Kein Mutation-Call
    write_calls = @mock.calls.select { |verb, action, _, _| verb == :post && %w[assignPlayer editTeilnehmerlisteSave].include?(action) }
    assert write_calls.empty?, "Validation-Fail darf KEIN Write-Call auslösen — got #{write_calls.inspect}"
  end

  test "Validation: player bereits in Teilnehmerliste → ToolError mit Duplicate-Liste" do
    # Edge-Case: player ist in BEIDEN Listen (CC-Data-Corruption-Szenario ODER User-Doppel-Add-Versuch).
    # Mock setzt 11683 in BEIDEN, damit der Duplicate-Check (NACH dem missing-from-meldeliste-Check) greift.
    McpServer::CcSession._client_override = build_stateful_mock(
      initial_teilnehmer: [[11683, "Nachtmann, Georg (11683)"]],
      initial_meldung: [[11683, "Nachtmann, Georg (11683)"], [10024, "Schröder, Hans-Jörg (10024)"]]
    )
    response = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_ids: [11683], # bereits in Teilnehmerliste
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      armed: true, server_context: nil
    )
    assert response.error?
    text = response.content.first[:text]
    assert_match(/already in Teilnehmerliste.*11683/, text)
    assert_match(/cc_remove_from_teilnehmerliste/, text)
  end

  # Plan 10-05.1 Task 1 (D-10-04-B Pivot): Phase-4-Schicht-3 (Production-Block) DEPRECATED.
  # Vorheriger Test entfernt. Pre-Validation-First-Pattern (Task 3) macht Tool zum Sicherheitsnetz.

  # --- AC-1 Validation: Schema + Input ---

  test "Validation: fehlendes tournament_cc_id → Missing-required-error" do
    response = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      player_cc_ids: [11683], server_context: nil
    )
    assert response.error?
    assert_match(/Missing required parameter/i, response.content.first[:text])
    assert_match(/tournament_cc_id/, response.content.first[:text])
    assert @mock.calls.empty?, "Required-Fail darf MockClient nicht erreichen"
  end

  test "Validation: leeres player_cc_ids Array → Invalid-input-error" do
    response = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_ids: [],
      server_context: nil
    )
    assert response.error?
    assert_match(/Invalid player_cc_ids/i, response.content.first[:text])
    assert_match(/at least 1 element/, response.content.first[:text])
  end

  # --- read_back:false skip ---

  test "read_back:false überspringt Read-Back-Call und liefert 'skipped' im Status" do
    response = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_ids: [11683],
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      armed: true, read_back: false, server_context: nil
    )
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    assert_match(/read_back_match: skipped/, response.content.first[:text])
    # Plan 33-fix: read_back:false → nur 1 editTeilnehmerlisteCheck (Pre-Read); kein Re-Render, kein Read-Back.
    check_calls = @mock.calls.select { |verb, action, _, _| verb == :post && action == "editTeilnehmerlisteCheck" }
    assert_equal 1, check_calls.size, "read_back:false → 1 editTeilnehmerlisteCheck (nur Pre-Read) — got #{check_calls.size}"
  end

  # --- Real-CC-Format-Parsing (NBV-only-Constraint-Vorbereitung) ---

  test "Real-CC-Format-Pre-Read: extract Tournament-Name + Teilnehmerliste-Options aus Real-CC-Style HTML" do
    # Real-CC-Style: kein Doppelpunkt nach "Meisterschaft" (wie in 07-02 Captures)
    real_cc_mock = McpServer::Tools::MockClient.new
    real_cc_mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      if action == "editTeilnehmerlisteCheck"
        body = <<~HTML
          <html><body>
          <form>
          <input type="hidden" name="fedId" value="20">
          <input type="hidden" name="branchId" value="8">
          <input type="hidden" name="disciplinId" value="*">
          <input type="hidden" name="season" value="2025/2026">
          <input type="hidden" name="catId" value="*">
          <input type="hidden" name="meisterTypeId" value="">
          <input type="hidden" name="meisterschaftsId" value="890">
          <input type="hidden" name="sortedBy" value="playername">
          <input type="hidden" name="firstEntry" value="1">
          <table>
            <tr><td>Meisterschaft</td><td>&nbsp;</td><td class="white" nowrap><b>Real CC NDM Endrunde Eurokegel</b></td></tr>
          </table>
          <select name="teilnehmerId" size="25"><option value="">&nbsp;</option></select>
          <select name="meldungId[]" multiple size="25">
            <option value="11683">Nachtmann, Georg (11683) - BC Wedel (1010)</option>
            <option value="10024">Schröder, Hans-Jörg (10024) - BC Wedel (1010)</option>
          </select>
          </form>
          </body></html>
        HTML
        [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
      else
        [Struct.new(:code, :message, :body).new("200", "OK", ""), Nokogiri::HTML("<html></html>")]
      end
    end
    McpServer::CcSession._client_override = real_cc_mock

    response = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_ids: [11683],
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      server_context: nil
    )
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    text = response.content.first[:text]
    assert_match(/Real CC NDM Endrunde Eurokegel/, text)
    assert_match(/11683.*Nachtmann/, text)
  end

  # --- Tool-Registration + Schema-Sanity ---

  test "Tool ist als cc_assign_player_to_teilnehmerliste registriert" do
    tools = McpServer::Server.collect_tools.map { |t| t.respond_to?(:tool_name) ? t.tool_name : nil }.compact
    assert_includes tools, "cc_assign_player_to_teilnehmerliste"
  end

  # --- Plan 26-01 T1 (2026-06-03): Race-Fix gegen Edit-Buffer-Stale-Bug aus Demo-1 ---

  test "Plan 26-01 T1: edit_buffer matches persisted (beide leer) → no override, no wait, persisted_truth_source=showTeilnehmerliste" do
    # Default-Setup: Edit-Buffer initial leer (teilnehmer=[]), persisted via Default-MockClient.get
    # liefert HTML ohne cc_bluelink-Anchor → fetch_teilnehmerliste_persisted = [].
    # Erwartung: 0 ≤ 0 → kein Stale, normaler Pfad, persisted_truth_source: "showTeilnehmerliste".
    response = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_ids: [11683],
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      armed: true, server_context: nil
    )
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    text = response.content.first[:text]
    assert_match(/persisted_truth_source: showTeilnehmerliste\b/, text)
    refute_match(/synced after wait/, text)
    refute_match(/persisted unavailable/, text)
    # showTeilnehmerliste muss exakt 1x via GET aufgerufen worden sein (initial sync check, kein retry).
    show_calls = @mock.calls.select { |verb, action, _, _| verb == :get && action == "showTeilnehmerliste" }
    assert_equal 1, show_calls.size, "fetch_teilnehmerliste_persisted muss 1x aufgerufen werden — got #{show_calls.size}"
    # Plan 33-fix: 2 editTeilnehmerlisteCheck (1 initial Pre-Read + 1 read-back); KEIN Re-Render mehr.
    pre_read_calls = @mock.calls.select { |verb, action, _, _| verb == :post && action == "editTeilnehmerlisteCheck" }
    assert_equal 2, pre_read_calls.size, "1 initial Pre-Read + 1 read-back — got #{pre_read_calls.size}"
  end

  test "Plan 26-01 T1: edit_buffer permanent stale (persisted=3, buffer=0) → abort vor Save mit Sportwart-Sprache" do
    # Worst-Case aus Demo-1: editTeilnehmerlisteCheck liefert teilnehmer=[] (stale leer),
    # showTeilnehmerliste liefert 3 persistierte Spieler.
    # Erwartung: Wait + Re-Read → immer noch stale → abort mit deutscher Nachricht; KEIN Schreibvorgang.
    persisted_body = <<~HTML
      <html><body>
        <a href="showTeilnehmer.php?p=20-8-x-2025/2026-x--890-3-10413" title="Auel, Wilfried (10413)" class="cc_bluelink">Auel</a>
        <a href="showTeilnehmer.php?p=20-8-x-2025/2026-x--890-3-10227" title="Jahn, Wilfried (10227)" class="cc_bluelink">Jahn</a>
        <a href="showTeilnehmer.php?p=20-8-x-2025/2026-x--890-3-10934" title="Weiss, Jeffrey (10934)" class="cc_bluelink">Weiss</a>
      </body></html>
    HTML

    helper = self.class
    meldung_initial = [[11683, "Nachtmann, Georg (11683)"], [10024, "Schröder, Hans-Jörg (10024)"]]
    stale_mock = McpServer::Tools::MockClient.new
    stale_mock.define_singleton_method(:get) do |action, params, opts|
      @calls << [:get, action, params, opts]
      if action == "showTeilnehmerliste"
        [Struct.new(:code, :message, :body).new("200", "OK", persisted_body), Nokogiri::HTML(persisted_body)]
      else
        [Struct.new(:code, :message, :body).new("200", "OK", ""), Nokogiri::HTML("")]
      end
    end
    stale_mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      if action == "editTeilnehmerlisteCheck"
        # Edit-Buffer-View bleibt stale (teilnehmer leer) bei JEDEM Re-Read.
        body = helper.build_check_html(teilnehmer_options: [], meldung_options: meldung_initial, tournament_name: "TEST Stale Buffer")
        [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
      else
        [Struct.new(:code, :message, :body).new("200", "OK", ""), Nokogiri::HTML("<html></html>")]
      end
    end
    McpServer::CcSession._client_override = stale_mock
    # Test-Beschleunigung: 0s Wait statt 1.5s.
    McpServer::Tools::AssignPlayerToTeilnehmerliste.edit_buffer_resync_wait_seconds = 0

    response = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_ids: [11683],
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      armed: true, server_context: nil
    )

    # Reset Wait-Konstante für andere Tests.
    McpServer::Tools::AssignPlayerToTeilnehmerliste.edit_buffer_resync_wait_seconds = 1.5

    assert response.error?, "Expected abort, got: #{response.content.first[:text]}"
    text = response.content.first[:text]
    assert_match(/ClubCloud braucht einen Moment/, text)
    assert_match(/gleich erneut versuchen/, text)
    assert_match(/3 Eintrag\(e\) in der Teilnehmerliste/, text)
    assert_match(/Schreibvorgang jetzt würde die anderen Einträge verlieren/, text)
    # CRITICAL: KEIN assignPlayer und KEIN editTeilnehmerlisteSave aufgerufen.
    write_calls = stale_mock.calls.select { |verb, action, _, _| verb == :post && %w[assignPlayer editTeilnehmerlisteSave].include?(action) }
    assert write_calls.empty?, "Abort darf NICHT in CC schreiben — got #{write_calls.inspect}"
    # 2 Pre-Reads (initial + 1 Retry nach Wait).
    pre_read_calls = stale_mock.calls.select { |verb, action, _, _| verb == :post && action == "editTeilnehmerlisteCheck" }
    assert_equal 2, pre_read_calls.size, "Sync-Guard: initial + 1 retry-after-wait — got #{pre_read_calls.size}"
    # AC-3 Sportwart-Sprache: KEINE Verbots-Begriffe in Fehler-Nachricht.
    %w[Flapping Eventual Caching Race-Condition Buffer Stale].each do |verboten|
      refute_match(/#{verboten}/, text, "Sportwart-Fehler darf '#{verboten}' nicht enthalten")
    end
  end
end
