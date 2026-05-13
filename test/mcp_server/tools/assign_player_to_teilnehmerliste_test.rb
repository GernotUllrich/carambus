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
      when "assignPlayer"
        # State-Mutation: move all meldungId[] entries from meldung → teilnehmer.
        added_ids = Array(params["meldungId[]"]).map(&:to_i)
        added_ids.each do |cc_id|
          moved = current_meldung.find { |id, _| id == cc_id }
          if moved
            current_teilnehmer << moved
            current_meldung.delete(moved)
          end
        end
        [Struct.new(:code, :message, :body).new("200", "OK", ""),
          Nokogiri::HTML("<html><body>MOCK POST assignPlayer OK</body></html>")]
      when "editTeilnehmerlisteSave"
        [Struct.new(:code, :message, :body).new("200", "OK", ""),
          Nokogiri::HTML("<html><body>MOCK POST editTeilnehmerlisteSave Saved</body></html>")]
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
    assert_match(/Workflow: assignPlayer.*Multi-Add.*editTeilnehmerlisteSave/, text)
    # Schicht 1: armed=false darf NIEMALS assignPlayer/Save aufrufen
    write_calls = @mock.calls.select { |verb, action, _, _| verb == :post && %w[assignPlayer editTeilnehmerlisteSave].include?(action) }
    assert write_calls.empty?, "Dry-Run darf assignPlayer/Save NICHT aufrufen — got #{write_calls.inspect}"
    # Pre-Read editTeilnehmerlisteCheck DARF aufgerufen werden
    pre_reads = @mock.calls.select { |verb, action, _, _| verb == :post && action == "editTeilnehmerlisteCheck" }
    assert_equal 1, pre_reads.size, "Dry-Run macht exakt 1 Pre-Read — got #{pre_reads.size}"
  end

  test "armed:true Single-Add ruft Pre-Read → assignPlayer → Save → Read-Back in genau dieser Reihenfolge" do
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
    # Reihenfolge: Pre-Read → assignPlayer → Re-Render → Save → Read-Back (Plan 07-04 Inline-Patch — Risk A)
    actions = @mock.calls.select { |verb, _, _, _| verb == :post }.map { |_, a, _, _| a }
    assert_equal ["editTeilnehmerlisteCheck", "assignPlayer", "editTeilnehmerlisteCheck", "editTeilnehmerlisteSave", "editTeilnehmerlisteCheck"], actions,
      "Erwarte Pre-Read → assignPlayer → Re-Render → Save → Read-Back — got #{actions.inspect}"
  end

  # --- AC-2 Multi-Add (Phase-7-Spezifikum) ---

  test "Multi-Add: player_cc_ids=[11683, 10024] erzeugt EINEN assignPlayer-Call mit meldungId[] Array" do
    response = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_ids: [11683, 10024],
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      armed: true, server_context: nil
    )
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    assert_match(/Assigned 2 player/, response.content.first[:text])
    # GENAU ein assignPlayer-Call mit Array-Payload
    assign_calls = @mock.calls.select { |verb, action, _, _| verb == :post && action == "assignPlayer" }
    assert_equal 1, assign_calls.size, "Multi-Add muss in EINEM Call passieren — got #{assign_calls.size}"
    _, _, payload, _ = assign_calls.first
    assert_equal [11683, 10024], Array(payload["meldungId[]"]),
      "meldungId[] muss Array mit beiden cc_ids sein — got #{payload["meldungId[]"].inspect}"
    # Verify count_after im Final-Text
    assert_match(/teilnehmerliste_count_after:  2/, response.content.first[:text])
  end

  test "Save-Payload enthält 9-Felder-Base + save=1 als non-blank Sentinel" do
    McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_ids: [11683],
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      armed: true, server_context: nil
    )
    save_call = @mock.calls.find { |verb, action, _, _| verb == :post && action == "editTeilnehmerlisteSave" }
    refute_nil save_call, "editTeilnehmerlisteSave muss aufgerufen worden sein"
    _, _, params, _ = save_call
    # 9-Felder-Base-Payload aus 07-02 SNIFF-OUTPUT.md §3 + save-Sentinel
    # Plan 07-04 Inline-Patch v2: zusätzlich :referer (wird vom Real-Client als HTTP-Header gesetzt, nicht im Body)
    required_keys = %i[fedId branchId disciplinId catId season meisterTypeId meisterschaftsId sortedBy firstEntry save]
    missing_keys = required_keys - params.keys
    assert_empty missing_keys, "Save-Payload fehlen Felder: #{missing_keys.inspect}; got #{params.keys.sort.inspect}"
    assert_equal "1", params[:save], "save-Sentinel muss '1' sein (D-7-6, non-blank fallthrough für client.post)"
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
    # 4 Calls (mit Inline-Patch Risk A): Pre-Read + assignPlayer + Re-Render + Save (kein Read-Back)
    check_calls = @mock.calls.select { |verb, action, _, _| verb == :post && action == "editTeilnehmerlisteCheck" }
    assert_equal 2, check_calls.size, "read_back:false → 2 editTeilnehmerlisteCheck (Pre-Read + Re-Render) — got #{check_calls.size}"
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
end
