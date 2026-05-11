# frozen_string_literal: true

require "test_helper"

# Tests für cc_update_tournament_deadline (Plan 06-03 Mock-Implementation).
# Mock-only Scope: keine Live-CC-Calls; Live-Validation ist Plan 06-04 (User-Action).
#
# Sicherheitsschichten-Coverage:
#   1. armed-Default false → Test 1 (dry-run mit Detail-Echo aller 8 Felder)
#   2. Mock-Mode-Default → setup nutzt _client_override mit MockClient
#   3. Rails-env-Check → Test 7 (production? blockiert armed:true)
#   4. Detail-Dry-Run-Echo → Test 1 (alle 8 Felder im Output, mschluss_old + mschluss_new)
#
# 2-Step-Workflow-Coverage (aus 06-02 SNIFF-OUTPUT.md):
#   Test 2: Pre-Read + editMeldelisteCheck → editMeldelisteSave + Read-Back in genau dieser Reihenfolge
#   Test 8: Read-Back-Mismatch erzeugt ToolError mit Cleanup-Hinweis
#
# OneOf-Validation + Date-Format + DB-first-Resolver → Tests 3-6.

class McpServer::Tools::UpdateTournamentDeadlineTest < ActiveSupport::TestCase
  # Builds a minimal showMeldeliste-Response-HTML with hidden inputs + HTML5 date inputs.
  # Mock-Format (Plan 06-03): HTML5 date inputs + text input — parser-friendly.
  # Real-CC-Format (Plan 06-04 Live-Test): german DD.MM.YYYY in <b> tags after labels — also supported by parser.
  def self.build_show_meldeliste_html(mschluss: "2026-05-26", name: "MOCK Meldeliste NDM",
    stag: "2026-01-01", fed_id: 20, branch_id: 8,
    season: "2025/2026", disciplin_id: "*", cat_id: "*",
    meldeliste_id: 1310)
    <<~HTML
      <html><body>
      <form name="billard" method="post">
      <input type="hidden" name="fedId" value="#{fed_id}">
      <input type="hidden" name="branchId" value="#{branch_id}">
      <input type="hidden" name="disciplinId" value="#{disciplin_id}">
      <input type="hidden" name="catId" value="#{cat_id}">
      <input type="hidden" name="season" value="#{season}">
      <input type="hidden" name="meldelisteId" value="#{meldeliste_id}">
      <input type="date" name="mschluss" value="#{mschluss}">
      <input type="date" name="stag" value="#{stag}">
      <input type="text" name="meldelistenName" value="#{name}">
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

  # Builds a stateful MockClient that simulates Save-persistence: after editMeldelisteSave,
  # subsequent showMeldeliste calls return the new mschluss. Enables Read-Back match testing.
  def build_stateful_mock(initial_mschluss: "2026-05-26", initial_name: "MOCK Meldeliste NDM",
    initial_stag: "2026-01-01", fed_id: 20, branch_id: 8,
    season: "2025/2026", meldeliste_id: 1310)
    current_mschluss = initial_mschluss
    current_name = initial_name
    current_stag = initial_stag
    helper = self.class
    mock = McpServer::Tools::MockClient.new
    mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      case action
      when "showMeldeliste"
        body = helper.build_show_meldeliste_html(
          mschluss: current_mschluss, name: current_name, stag: current_stag,
          fed_id: fed_id, branch_id: branch_id, season: season, meldeliste_id: meldeliste_id
        )
        [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
      when "editMeldelisteSave"
        current_mschluss = params[:mschluss] if params[:mschluss]
        current_name = params[:meldelistenName] if params[:meldelistenName]
        current_stag = params[:stag] if params[:stag]
        [Struct.new(:code, :message, :body).new("200", "OK", ""),
          Nokogiri::HTML("<html><body>MOCK POST editMeldelisteSave Saved</body></html>")]
      else
        # editMeldelisteCheck + any other action: bare OK response
        [Struct.new(:code, :message, :body).new("200", "OK", ""),
          Nokogiri::HTML("<html><body>MOCK POST #{action} OK</body></html>")]
      end
    end
    mock
  end

  # --- AC-1 (Schicht 1+3+4 + Validation) ---

  test "armed:false (default) returns Detail-Echo mit allen 8 Detail-Feldern + mschluss_old/new ohne Save" do
    response = McpServer::Tools::UpdateTournamentDeadline.call(
      meldeliste_cc_id: 1310, new_deadline: "2026-06-09",
      server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    # Schicht 4: alle 8 Detail-Felder im Dry-Run-Output
    assert_match(/\[DRY-RUN\] Would update Meldeschluss for meldeliste_cc_id=1310/, text)
    assert_match(/MOCK Meldeliste NDM/, text)
    assert_match(/mschluss_old: 2026-05-26/, text)
    assert_match(/mschluss_new: 2026-06-09/, text)
    assert_match(/fed_id=20/, text)
    assert_match(/branch_cc_id=8/, text)
    assert_match(/season=2025\/2026/, text)
    assert_match(/disciplin_id=\*/, text)
    assert_match(/cat_id=\*/, text)
    assert_match(/stag=2026-01-01.*unchanged/, text)
    assert_match(/Workflow: 2-Step POST/, text)
    assert_match(/Pass armed:true to actually perform/, text)
    # Schicht 1: armed=false darf NIEMALS editMeldelisteSave aufrufen
    save_calls = @mock.calls.select { |verb, action, _, _| verb == :post && action == "editMeldelisteSave" }
    assert save_calls.empty?, "Dry-Run darf editMeldelisteSave NICHT aufrufen — got #{save_calls.inspect}"
    # Pre-Read showMeldeliste DARF aufgerufen werden (read-only)
    pre_reads = @mock.calls.select { |verb, action, _, _| verb == :post && action == "showMeldeliste" }
    assert_equal 1, pre_reads.size, "Dry-Run macht exakt 1 Pre-Read showMeldeliste — got #{pre_reads.size}"
  end

  test "armed:true ruft Pre-Read + 2-Step Save + Read-Back in genau dieser Reihenfolge" do
    response = McpServer::Tools::UpdateTournamentDeadline.call(
      meldeliste_cc_id: 1310, new_deadline: "2026-06-09",
      armed: true, server_context: nil
    )
    refute response.error?, "Expected success, got error: #{response.content.first[:text]}"
    text = response.content.first[:text]
    assert_match(/Updated Meldeschluss for meldeliste_cc_id=1310 \(MOCK Meldeliste NDM\)/, text)
    assert_match(/2026-05-26 → 2026-06-09/, text)
    assert_match(/read_back_match: true/, text)

    # Reihenfolge: showMeldeliste (Pre-Read) → editMeldelisteCheck → editMeldelisteSave → showMeldeliste (Read-Back)
    actions = @mock.calls.select { |verb, _, _, _| verb == :post }.map { |_, a, _, _| a }
    assert_equal ["showMeldeliste", "editMeldelisteCheck", "editMeldelisteSave", "showMeldeliste"], actions,
      "Erwarte Pre-Read → Check → Save → Read-Back — got #{actions.inspect}"
  end

  test "Schicht 3: armed:true in Rails production env wird mit error blockiert (kein CC-Call)" do
    Rails.env.stub(:production?, true) do
      response = McpServer::Tools::UpdateTournamentDeadline.call(
        meldeliste_cc_id: 1310, new_deadline: "2026-06-09",
        armed: true, server_context: nil
      )
      assert response.error?
      assert_match(/blocked in Rails production/, response.content.first[:text])
    end
    # Schicht 3 fail-fast: kein CC-Call darf passieren (auch kein Pre-Read)
    assert @mock.calls.empty?, "Production-blocked Tool darf MockClient NICHT aufrufen — got #{@mock.calls.inspect}"
  end

  # --- AC-2 (Save-Payload-Korrektheit) ---

  test "Save-Payload enthält alle 9 Felder mit mschluss=new_deadline und button-Names save/nbut als Sentinel" do
    McpServer::Tools::UpdateTournamentDeadline.call(
      meldeliste_cc_id: 1310, new_deadline: "2026-06-09",
      armed: true, server_context: nil
    )
    save_call = @mock.calls.find { |verb, action, _, _| verb == :post && action == "editMeldelisteSave" }
    refute_nil save_call, "editMeldelisteSave muss aufgerufen worden sein"
    _, _, params, _ = save_call
    # 9-Felder-Payload aus 06-02 SNIFF-OUTPUT.md §3 Step 2
    expected_keys = %i[fedId branchId disciplinId catId season meldelisteId meldelistenName mschluss stag save].sort
    assert_equal expected_keys, params.keys.sort,
      "Save-Payload muss genau 9 Felder + save-Sentinel haben — got #{params.keys.sort.inspect}"
    assert_equal "2026-06-09", params[:mschluss], "mschluss muss neuer Wert sein"
    assert_equal "MOCK Meldeliste NDM", params[:meldelistenName], "meldelistenName muss aus Pre-Read durchgereicht werden (D-5)"
    assert_equal "2026-01-01", params[:stag], "stag muss aus Pre-Read durchgereicht werden (D-5)"
    assert_equal "1", params[:save], "save-Sentinel muss '1' sein (D-6, non-blank fallthrough für client.post)"

    # Check-Payload sollte 6 Scope-Filter + nbut-Sentinel haben
    check_call = @mock.calls.find { |verb, action, _, _| verb == :post && action == "editMeldelisteCheck" }
    refute_nil check_call, "editMeldelisteCheck muss aufgerufen worden sein"
    _, _, check_params, _ = check_call
    expected_check_keys = %i[fedId branchId disciplinId catId season meldelisteId nbut].sort
    assert_equal expected_check_keys, check_params.keys.sort,
      "Check-Payload muss 6 Scope-Filter + nbut haben — got #{check_params.keys.sort.inspect}"
    assert_equal "1", check_params[:nbut], "nbut-Sentinel muss '1' sein (D-6)"
  end

  # --- OneOf-Validation + Date-Format + DB-Resolver ---

  test "Validation: fehlende tournament_cc_id und meldeliste_cc_id beide → OneOf-error" do
    response = McpServer::Tools::UpdateTournamentDeadline.call(
      new_deadline: "2026-06-09", server_context: nil
    )
    assert response.error?
    assert_match(/one of tournament_cc_id or meldeliste_cc_id/i, response.content.first[:text])
    # Validation muss vor jedem CC-Call passieren
    assert @mock.calls.empty?, "OneOf-Fail darf MockClient nicht erreichen — got #{@mock.calls.inspect}"
  end

  test "Validation: invalides Datums-Format (DD.MM.YYYY statt ISO) → error 'YYYY-MM-DD expected'" do
    response = McpServer::Tools::UpdateTournamentDeadline.call(
      meldeliste_cc_id: 1310, new_deadline: "09.06.2026", server_context: nil
    )
    assert response.error?
    assert_match(/YYYY-MM-DD/, response.content.first[:text])
    assert @mock.calls.empty?, "Format-Fail darf MockClient nicht erreichen"
  end

  test "Validation: fehlendes new_deadline → required-error" do
    response = McpServer::Tools::UpdateTournamentDeadline.call(
      meldeliste_cc_id: 1310, server_context: nil
    )
    assert response.error?
    assert_match(/Missing required parameter/i, response.content.first[:text])
    assert_match(/new_deadline/, response.content.first[:text])
  end

  test "DB-Resolver: tournament_cc_id ohne resolvbare meldeliste → error mit Override-Hinweis" do
    # cc_id=99999999 ist garantiert nicht in DB → resolver liefert nil
    response = McpServer::Tools::UpdateTournamentDeadline.call(
      tournament_cc_id: 99999999, new_deadline: "2026-06-09", server_context: nil
    )
    assert response.error?
    assert_match(/Cannot resolve meldeliste_cc_id/, response.content.first[:text])
    assert_match(/Pass meldeliste_cc_id directly/, response.content.first[:text])
  end

  # --- Read-Back-Mismatch (Schicht 4 Verify) ---

  test "Read-Back-Mismatch (Save persistiert nicht den neuen Wert) → ToolError mit Cleanup-Hinweis" do
    # Custom mock: editMeldelisteSave wird ignoriert (Mock-Save schlägt fehl); Pre-Read und Read-Back
    # liefern den ALTEN Wert → mschluss_after != new_deadline → Mismatch erwartet.
    silent_mock = McpServer::Tools::MockClient.new
    helper = self.class
    silent_mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      if action == "showMeldeliste"
        body = helper.build_show_meldeliste_html(mschluss: "2026-05-26")
        [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
      else
        [Struct.new(:code, :message, :body).new("200", "OK", ""), Nokogiri::HTML("<html></html>")]
      end
    end
    McpServer::CcSession._client_override = silent_mock

    response = McpServer::Tools::UpdateTournamentDeadline.call(
      meldeliste_cc_id: 1310, new_deadline: "2026-06-09",
      armed: true, read_back: true, server_context: nil
    )
    assert response.error?
    assert_match(/Read-back mismatch/, response.content.first[:text])
    assert_match(/expected mschluss=2026-06-09/, response.content.first[:text])
    assert_match(/got "2026-05-26"/, response.content.first[:text])
    assert_match(/Inspect CC UI manually/, response.content.first[:text])
  end

  # --- read_back:false skip ---

  test "read_back:false überspringt Read-Back-Call und liefert 'skipped' im Status" do
    response = McpServer::Tools::UpdateTournamentDeadline.call(
      meldeliste_cc_id: 1310, new_deadline: "2026-06-09",
      armed: true, read_back: false, server_context: nil
    )
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    assert_match(/read_back_match: skipped/, response.content.first[:text])
    # Nur 3 Calls: Pre-Read + Check + Save (kein 2. showMeldeliste)
    show_calls = @mock.calls.select { |verb, action, _, _| verb == :post && action == "showMeldeliste" }
    assert_equal 1, show_calls.size, "read_back:false → nur 1 showMeldeliste (Pre-Read) — got #{show_calls.size}"
  end

  # --- Real-CC-Format-Parsing (NBV-only-Constraint-Vorbereitung) ---

  test "Real-CC-Format-Pre-Read: <b>DD.MM.YYYY</b>-Display wird zu ISO konvertiert" do
    # Real-CC-style showMeldeliste-Response (Label-based, German date format in <b> tags).
    real_cc_mock = McpServer::Tools::MockClient.new
    real_cc_mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      if action == "showMeldeliste"
        body = <<~HTML
          <html><body>
          <form>
            <input type="hidden" name="fedId" value="20">
            <input type="hidden" name="branchId" value="8">
            <input type="hidden" name="disciplinId" value="*">
            <input type="hidden" name="catId" value="*">
            <input type="hidden" name="season" value="2025/2026">
            <input type="hidden" name="meldelisteId" value="1310">
          </form>
          <table>
          <tr><td>Meldeliste:</td><td><b>Real CC Meldeliste</b></td></tr>
          <tr><td>Meldeschluss:</td><td><b>26.05.2026</b></td></tr>
          <tr><td>Stichtag:</td><td><b>01.01.2026</b></td></tr>
          </table>
          </body></html>
        HTML
        [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
      else
        [Struct.new(:code, :message, :body).new("200", "OK", ""), Nokogiri::HTML("<html></html>")]
      end
    end
    McpServer::CcSession._client_override = real_cc_mock

    response = McpServer::Tools::UpdateTournamentDeadline.call(
      meldeliste_cc_id: 1310, new_deadline: "2026-06-09", server_context: nil
    )
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    text = response.content.first[:text]
    # Parser MUSS deutsch DD.MM.YYYY zu ISO konvertieren
    assert_match(/mschluss_old: 2026-05-26/, text)
    assert_match(/stag=2026-01-01/, text)
    assert_match(/Real CC Meldeliste/, text)
  end
end
