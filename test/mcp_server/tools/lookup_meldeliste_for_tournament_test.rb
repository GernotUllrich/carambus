# frozen_string_literal: true

require "test_helper"

# Tests für cc_lookup_meldeliste_for_tournament (Plan 08-02 Mock-Implementation).
# Mock-only Scope; Live-Validation ist Plan 08-03.
#
# 0/1/≥2-Disambiguation-Coverage (D-08-E):
#   Test 1: 0 Treffer → error
#   Test 2: 1 Treffer (Mock-CC) → top-level meldeliste_cc_id
#   Test 3: ≥2 Treffer (Mock-CC) → candidates-Array + warning
#   Test 4: force_refresh:true → skip DB, query CC
#
# DB-first ist optional — Pre-Lookup-Pfad ist defensiv (rescue + fallback auf Live-CC),
# Tests fokussieren auf CC-Lookup-Pfad weil TournamentCc-Fixtures projektspezifisch fragil sind.

class McpServer::Tools::LookupMeldelisteForTournamentTest < ActiveSupport::TestCase
  setup do
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

  test "0 Treffer: Mock liefert leeren HTML → diagnostic error mit Workaround-Hinweis (Plan 10-02 Task 1)" do
    # Default-MockClient body=""; aber post liefert generic "MOCK POST ..." → keine Anchors → 0 candidates
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = "<html><body><p>Keine Meldelisten gefunden</p></body></html>"
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    response = McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 99999, force_refresh: true, server_context: nil
    )
    assert response.error?
    text = response.content.first[:text]
    # Plan 14-G.12-Hotfix #2: Diagnose-Message statt „LSW kontaktieren"-Pseudo-Diagnose.
    # Bei fehlenden Scope-Params → FEHLENDE PARAMS-Hint; CC-API-Hierarchie-Pattern erklärt.
    assert_match(/Resolver konnte Meldeliste nicht finden/i, text)
    assert_match(/tournament_cc_id=99999/, text)
    assert_match(/meisterschaftsId=99999/, text)
    # Anti-Regression: alte False-Claim darf NICHT mehr im Output sein
    refute_match(/has no Meldelisten/, text)
    refute_match(/Workaround: pass meldeliste_cc_id directly/, text, "F-6: Entwickler-Workaround-Sprache raus")
  end

  test "Plan 10-02 Retry-Fallback: scope-filter 0 Treffer → retry mit meisterschaftsId-Pfad (Befund #5)" do
    call_count = 0
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      call_count += 1
      # 1. Call (scope-filter-Pfad): 0 Treffer
      # 2. Call (retry mit meisterschaftsId): 1 Treffer 1310
      body = if call_count == 1
        "<html><body><p>Keine Meldelisten gefunden</p></body></html>"
      else
        '<html><body><tr data-meldeliste-cc-id="1310"><td>NDM Endrunde Eurokegel</td></tr></body></html>'
      end
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    response = McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 890,
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      force_refresh: true, server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    assert_match(/meldeliste_cc_id: 1310/, text)
    # 2 Calls erwartet (initial scope-filter + retry meisterschaftsId)
    # Plan 14-02.3 / F-5: fetch_meldeliste_overview (GET editMeldelisteCheck) läuft als Pfad 1
    # → +1 GET-Call vor den POST-Calls. Tests filtern jetzt auf POSTs.
    posts = @mock.calls.select { |verb, _, _, _| verb == :post }
    assert_equal 2, posts.size, "Retry-Fallback muss 2 POST-Calls (Scope-Filter + meisterschaftsId) ausgelöst haben"
    # 1. POST: scope-filter payload — enthält seit DEFER-25-4-Fix auch meisterschaftsId
    payload_1 = posts[0][2]
    assert_equal 20, payload_1[:fedId]
    assert_equal 890, payload_1[:meisterschaftsId]
    # 2. POST: meisterschaftsId fallback payload
    payload_2 = posts[1][2]
    assert_equal 890, payload_2[:meisterschaftsId]
    refute payload_2.key?(:fedId)
  end

  test "Plan 10-02 Retry-Fallback: beide Pfade 0 Treffer → diagnostic error nennt beide attempted modes" do
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = "<html><body><p>Nothing</p></body></html>"
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    response = McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 890,
      fed_cc_id: 20, branch_cc_id: 8,
      force_refresh: true, server_context: nil
    )
    assert response.error?
    text = response.content.first[:text]
    # Plan 14-G.12-Hotfix #2: Diagnose-Message — entweder „FEHLENDE PARAMS" (wenn Scope-Lücke)
    # oder „nicht ableiten" (wenn alle Scope-Params gesetzt aber 0 Treffer).
    # Hier: fed/branch gesetzt, season fehlt → FEHLENDE PARAMS branch passt schon, season-Hint.
    assert_match(/Resolver konnte Meldeliste nicht (finden|ableiten)/i, text)
    assert_match(/scope-filter/, text)
    assert_match(/retry-meisterschaftsId-fallback/, text)
  end

  test "1 Treffer (Mock-HTML5 data-Attribut): top-level meldeliste_cc_id + candidates" do
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = <<~HTML
        <html><body><table>
          <tr data-meldeliste-cc-id="1310"><td>NDM Endrunde Eurokegel Quali Niederbayern</td></tr>
        </table></body></html>
      HTML
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    response = McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 890, force_refresh: true, server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    assert_match(/meldeliste_cc_id: 1310/, text)
    assert_match(/1 candidate found/, text)
    assert_match(/NDM Endrunde Eurokegel/, text)
  end

  test "≥2 Treffer (Mock-HTML5): candidates-Array + warning bei N:1-Disambiguation" do
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = <<~HTML
        <html><body><table>
          <tr data-meldeliste-cc-id="1310"><td>Quali Niederbayern</td></tr>
          <tr data-meldeliste-cc-id="1311"><td>Quali Oberbayern</td></tr>
          <tr data-meldeliste-cc-id="1312"><td>Quali Mittelfranken</td></tr>
        </table></body></html>
      HTML
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    response = McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 890, force_refresh: true, server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    assert_match(/meldeliste_cc_id: \(unresolved/, text)
    assert_match(/warning: Multiple Meldelisten found \(3\)/, text)
    assert_match(/1310/, text)
    assert_match(/1311/, text)
    assert_match(/1312/, text)
  end

  test "Anchor-Heuristik (Variante B): meldelisteId-Query-Param wird extrahiert" do
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      # KEIN data-Attribut → Fallback auf Anchor-Heuristik
      body = <<~HTML
        <html><body>
          <a href="/admin/einzel/meldelisten/showMeldeliste.php?meldelisteId=2001">Liste A</a>
          <a href="/admin/einzel/meldelisten/showMeldeliste.php?meldelisteId=2002">Liste B</a>
        </body></html>
      HTML
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    response = McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 890, force_refresh: true, server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    # 2 Treffer → unresolved + warning
    assert_match(/Multiple Meldelisten found \(2\)/, text)
    assert_match(/2001/, text)
    assert_match(/2002/, text)
  end

  test "Required-Parameter-Validation: tournament_cc_id REQUIRED" do
    response = McpServer::Tools::LookupMeldelisteForTournament.call(server_context: nil)
    assert response.error?
    text = response.content.first[:text]
    assert_match(/Missing required parameter/, text)
    assert @mock.calls.empty?
  end

  test "force_refresh:true erzwingt Live-CC-Call auch bei DB-Treffer (defensiv)" do
    # Mock liefert 1 Treffer auf CC-Side
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = '<html><body><tr data-meldeliste-cc-id="9999"><td>Force-Refresh-Result</td></tr></body></html>'
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    response = McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 890, force_refresh: true, server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    assert_match(/meldeliste_cc_id: 9999/, text)
    # force_refresh:true MUSS Live-CC-Call gemacht haben
    posts = @mock.calls.select { |verb, _, _, _| verb == :post }
    actions = posts.map { |_, action, _, _| action }
    assert_includes actions, "showMeldelistenList"
  end

  # ─── Plan 09-02: Scope-Filter-Hybrid-POST-Logik (v0.2.1-Konsolidierung) ──────────

  test "Plan 09-02 T-Scope-Full: alle 5 Scope-Filter → POST mit Scope-Filter-Payload (KEIN meisterschaftsId)" do
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = '<html><body><tr data-meldeliste-cc-id="1310"><td>Quali NBV</td></tr></body></html>'
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    response = McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 890,
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      disciplin_id: "*", cat_id: "100",
      force_refresh: true, server_context: nil
    )
    refute response.error?
    posts = @mock.calls.select { |verb, action, _, _| verb == :post && action == "showMeldelistenList" }
    assert_equal 1, posts.size
    payload = posts.first[2]
    assert_equal 20, payload[:fedId]
    assert_equal 8, payload[:branchId]
    assert_equal "2025/2026", payload[:season]
    assert_equal "*", payload[:disciplinId]
    assert_equal "100", payload[:catId]
    assert_equal 890, payload[:meisterschaftsId], "DEFER-25-4: Scope-Filter-Payload muss meisterschaftsId enthalten"
  end

  # Bug B (2026-06-19): season nicht explizit gegeben → path-3 ergänzt sie aus dem
  # effective_season-Default (vorher fälschlich roh = nil durchgereicht). Deterministisch
  # via Stub, damit der Test nicht von Season-Fixtures/Datum abhängt.
  test "Plan 09-02 T-Scope-Partial: fed+branch explizit, season fehlt → aus effective_season-Default ergänzt (Bug B)" do
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = '<html><body><tr data-meldeliste-cc-id="1310"><td>Result</td></tr></body></html>'
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    season_stub = Struct.new(:name).new("2025/2026")
    McpServer::Tools::LookupMeldelisteForTournament.stub(:effective_season, season_stub) do
      McpServer::Tools::LookupMeldelisteForTournament.call(
        tournament_cc_id: 890, fed_cc_id: 20, branch_cc_id: 8,
        force_refresh: true, server_context: nil
      )
    end
    # Plan 14-02.3 / F-5: filter auf erste POST-Call (GET editMeldelisteCheck ist Pfad-1-Probe)
    payload = @mock.calls.find { |verb, _, _, _| verb == :post }[2]
    assert_equal 20, payload[:fedId]
    assert_equal 8, payload[:branchId]
    assert_equal "2025/2026", payload[:season], "Bug B: season wird aus effective_season-Default ergänzt"
    refute payload.key?(:catId), "cat_id nicht gesetzt → kein Key"
    assert_equal 890, payload[:meisterschaftsId], "DEFER-25-4: Scope-Filter-Payload muss meisterschaftsId enthalten"
  end

  test "Plan 09-02 T-Scope-Default-Disciplin: disciplin_id omitted → Wildcard '*' im Payload" do
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = '<html><body><tr data-meldeliste-cc-id="1310"><td>Result</td></tr></body></html>'
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 890, fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      # disciplin_id + cat_id NICHT gesetzt
      force_refresh: true, server_context: nil
    )
    # Plan 14-02.3 / F-5: filter auf erste POST-Call (GET editMeldelisteCheck ist Pfad-1-Probe)
    payload = @mock.calls.find { |verb, _, _, _| verb == :post }[2]
    assert_equal "*", payload[:disciplinId], "disciplin_id-Default ist Wildcard '*'"
  end

  # Bug B (2026-06-19): „kein Scope" heißt jetzt „nichts auflösbar". Wenn weder explizite
  # Params noch effective-Defaults (fed/season) noch ein ableitbarer Branch vorliegen, bleibt
  # der reine meisterschaftsId-Pfad (Plan-08-02-Fallback). Resolver via Stub auf nil gezwungen,
  # damit der Test diesen echten Fallback prüft statt von Fixtures/Datum/Context abzuhängen.
  test "Plan 09-02 T-Backwards-Compat: nichts auflösbar → reiner meisterschaftsId-Pfad" do
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = '<html><body><tr data-meldeliste-cc-id="1310"><td>Result</td></tr></body></html>'
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    tool = McpServer::Tools::LookupMeldelisteForTournament
    tool.stub(:resolve_tournament_branch_cc_id, nil) do
      tool.stub(:default_fed_id, nil) do
        tool.stub(:effective_season, nil) do
          tool.call(tournament_cc_id: 890, force_refresh: true, server_context: nil)
        end
      end
    end
    # Plan 14-02.3 / F-5: filter auf erste POST-Call (GET editMeldelisteCheck ist Pfad-1-Probe)
    payload = @mock.calls.find { |verb, _, _, _| verb == :post }[2]
    assert_equal 890, payload[:meisterschaftsId], "Backwards-Compat: meisterschaftsId muss gesendet werden"
    refute payload.key?(:fedId), "Nichts auflösbar → KEIN Scope-Filter-Key"
    refute payload.key?(:branchId)
    refute payload.key?(:season)
  end

  # Bug B (2026-06-19) Regression: ohne explizite Scope-Params, aber mit auflösbarem
  # server_context-Default (fed/season) + aus dem Turnier ableitbarem Branch, MUSS path-3
  # den vollständigen Scope-Tupel an die CC senden. Vorher reichte path-3 die rohen nil-Werte
  # durch → nur branchId → CC-Pool-Default → 0 Treffer (Live-Befund „NDM Test Cadre 35/2").
  test "Bug B: server_context-Default-Scope (fed/branch/season) wird in path-3 ergänzt" do
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = '<html><body><tr data-meldeliste-cc-id="1347"><td>NDM Test Cadre 35/2</td></tr></body></html>'
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    season_stub = Struct.new(:name).new("2025/2026")
    tool = McpServer::Tools::LookupMeldelisteForTournament
    tool.stub(:default_fed_id, 20) do
      tool.stub(:effective_season, season_stub) do
        tool.stub(:resolve_tournament_branch_cc_id, 10) do
          tool.call(tournament_cc_id: 939, force_refresh: true, server_context: nil)
        end
      end
    end
    payload = @mock.calls.find { |verb, _, _, _| verb == :post }[2]
    assert_equal 939, payload[:meisterschaftsId]
    assert_equal 20, payload[:fedId], "Bug B: fedId aus effective_fed (default_fed_id) ergänzt"
    assert_equal 10, payload[:branchId], "Bug B: branchId aus dem Turnier abgeleitet"
    assert_equal "2025/2026", payload[:season], "Bug B: season aus effective_season ergänzt"
  end

  test "Plan 09-02 T-Scope-Mixed-mit-Force-Refresh: Scope-Filter + force_refresh:true → Live-CC mit Scope-Payload, source=cc-live" do
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = '<html><body><tr data-meldeliste-cc-id="1310"><td>Live-Source-Result</td></tr></body></html>'
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    response = McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 890,
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      disciplin_id: "30", cat_id: "100",
      force_refresh: true, server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    assert_match(/meldeliste_cc_id: 1310/, text)
    assert_match(/cc-live/, text, "source:cc-live muss in candidates-Output stehen")
    # Plan 14-02.3 / F-5: filter auf erste POST-Call (GET editMeldelisteCheck ist Pfad-1-Probe)
    payload = @mock.calls.find { |verb, _, _, _| verb == :post }[2]
    assert_equal 20, payload[:fedId]
    assert_equal "30", payload[:disciplinId]
  end

  # ─── Plan 14-02.3 / F-5: Live-CC-Overview-Primary-Pfad ────────────────────────

  test "F-5 Live-CC-Overview primary: editMeldelisteCheck liefert meldelisteId → source=live-cc-overview" do
    overview_html = <<~HTML
      <html><body>
        <form>
          <input type="hidden" name="meldelisteId" value="2912">
          <select name="clubId">
            <option value="*">Alle Clubs</option>
            <option value="100">BC Werl</option>
            <option value="200">SV München</option>
          </select>
        </form>
      </body></html>
    HTML
    @mock.define_singleton_method(:get) do |action, get_options = {}, opts = {}|
      @calls << [:get, action, get_options, opts]
      [Struct.new(:code, :message, :body).new("200", "OK", overview_html), Nokogiri::HTML(overview_html)]
    end

    response = McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 912, server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    assert_match(/meldeliste_cc_id: 2912/, text)
    assert_match(/source: live-cc-overview/, text)
    assert_match(/clubs_count: 2/, text, "2 Clubs in overview (BC Werl + SV München; * ist filter, kein Club)")

    # Live-CC-primary darf KEINEN POST-Call ausgelöst haben (Legacy ist Pfad 3)
    posts = @mock.calls.select { |verb, _, _, _| verb == :post }
    assert_empty posts, "Live-CC-primary darf NICHT in Legacy-Pfad fallen wenn Pfad 1 erfolgreich"

    # 1 GET-Call auf editMeldelisteCheck
    gets = @mock.calls.select { |verb, action, _, _| verb == :get && action == "editMeldelisteCheck" }
    assert_equal 1, gets.size
  end

  test "F-5 Live-CC-Overview leer: kein meldelisteId-Pattern → Fallback auf Legacy-Pfad" do
    # GET liefert HTML ohne meldeliste_cc_id-Pattern → parse_meldeliste_cc_id returns nil
    @mock.define_singleton_method(:get) do |action, get_options = {}, opts = {}|
      @calls << [:get, action, get_options, opts]
      empty_html = "<html><body><p>Login required</p></body></html>"
      [Struct.new(:code, :message, :body).new("200", "OK", empty_html), Nokogiri::HTML(empty_html)]
    end
    # POST liefert legacy-Treffer
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = '<html><body><tr data-meldeliste-cc-id="9999"><td>Legacy-Match</td></tr></body></html>'
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end

    response = McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 890, force_refresh: true, server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    assert_match(/meldeliste_cc_id: 9999/, text)
    # Legacy-Source erwartet (1 candidate found → showMeldelistenList-Pfad)
    assert_match(/1 candidate found/, text)
  end

  test "F-5 Live-CC-Overview HTTP-Fehler: nil-Return → Fallback (defensive)" do
    @mock.define_singleton_method(:get) do |action, get_options = {}, opts = {}|
      @calls << [:get, action, get_options, opts]
      [Struct.new(:code, :message, :body).new("500", "Internal Server Error", ""), Nokogiri::HTML("<html></html>")]
    end
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = '<html><body><tr data-meldeliste-cc-id="9999"><td>Legacy</td></tr></body></html>'
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end

    response = McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 890, force_refresh: true, server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    # Fallback auf Legacy-Pfad erfolgreich
    assert_match(/meldeliste_cc_id: 9999/, text)
  end

  # ─── Plan 14-02.3 / F-5 CcSession Helper-Unit-Tests ───────────────────────────

  test "CcSession.parse_meldeliste_cc_id: input-Pattern A" do
    doc = Nokogiri::HTML('<html><body><input name="meldelisteId" value="2912"></body></html>')
    assert_equal 2912, McpServer::CcSession.parse_meldeliste_cc_id(doc)
  end

  test "CcSession.parse_meldeliste_cc_id: anchor-Pattern C" do
    doc = Nokogiri::HTML('<html><body><a href="/show.php?meldelisteId=3033">link</a></body></html>')
    assert_equal 3033, McpServer::CcSession.parse_meldeliste_cc_id(doc)
  end

  test "CcSession.parse_meldeliste_cc_id: data-Attribut-Pattern D" do
    doc = Nokogiri::HTML('<html><body><tr data-meldeliste-cc-id="4044"><td>x</td></tr></body></html>')
    assert_equal 4044, McpServer::CcSession.parse_meldeliste_cc_id(doc)
  end

  test "CcSession.parse_meldeliste_cc_id: kein Pattern → nil" do
    doc = Nokogiri::HTML("<html><body><p>nothing</p></body></html>")
    assert_nil McpServer::CcSession.parse_meldeliste_cc_id(doc)
  end

  test "CcSession.parse_clubs_overview: select-Pattern liefert Hash[id => name]" do
    doc = Nokogiri::HTML(<<~HTML)
      <html><body><select name="clubId">
        <option value="*">Alle</option>
        <option value="100">BC Werl</option>
        <option value="200">SV München</option>
      </select></body></html>
    HTML
    result = McpServer::CcSession.parse_clubs_overview(doc)
    assert_equal({100 => "BC Werl", 200 => "SV München"}, result)
  end

  # ---------------------------------------------------------------------------
  # Plan 14-G.12 Task 2 — Sportwart-Discovery-Pfad (club-scoped showMeldelistenList)
  # ---------------------------------------------------------------------------
  # Substrate: HTML-Save aus 2026-05-16-Walkthrough mit BC Wedel (clubId=1010),
  # Branch Kegel (branchId=8), Saison 2025/2026: 8 Meldelisten in der Liste,
  # davon „NDM Endrunde Eurokegel [1 Meldungen]" = meldelisteId 1310.

  SPORTWART_LIST_HTML = <<~HTML.freeze
    <html><body>
    <select name="meldelisteId" size="15">
      <option value="1264">1. Quali NDM Eurokegel [7 Meldungen]</option>
      <option value="1288">2. Quali NDM Eurokegel [8 Meldungen]</option>
      <option value="1310">NDM Endrunde Eurokegel [1 Meldungen]</option>
      <option value="1291">NDM Jugend Eurokegel </option>
    </select>
    </body></html>
  HTML

  test "Plan 14-G.12: Sportwart-Pfad mit club_cc_id liefert meldeliste_cc_id via TournamentCc.name-Match" do
    # TournamentCc-Fixture für Tournament-Name-Match
    tcc = TournamentCc.create!(cc_id: 890, context: "nbv", name: "NDM Endrunde Eurokegel")

    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = SPORTWART_LIST_HTML
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end

    response = McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 890,
      club_cc_id: 1010,
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      server_context: nil
    )
    refute response.error?, "Sportwart-Pfad sollte 1 Treffer liefern"
    text = response.content.first[:text]
    assert_match(/meldeliste_cc_id: 1310/, text)
    assert_match(/sportwart-showMeldelistenList/, text)
    assert_match(/club_cc_id=1010/, text)

    # Erster POST muss sportwart-showMeldelistenList sein mit clubId-Payload
    posts = @mock.calls.select { |verb, _, _, _| verb == :post }
    assert posts.any?, "Mindestens 1 POST-Call erwartet"
    first_post = posts.first
    assert_equal "sportwart-showMeldelistenList", first_post[1]
    assert_equal 1010, first_post[2][:clubId]
    assert_equal 20, first_post[2][:fedId]
    assert_equal 8, first_post[2][:branchId]
  ensure
    tcc&.destroy
  end

  test "Plan 14-G.12: Sportwart-Pfad ohne club_cc_id → Fall-through zu legacy-Pfaden (Backwards-Compat)" do
    # Mock liefert show-Meldelistenliste-HTML mit anchor-Tag für legacy fetch_from_cc
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = '<html><body><a href="/show.php?meldelisteId=1310">NDM Endrunde Eurokegel</a></body></html>'
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end

    response = McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 890,
      # KEIN club_cc_id → Fall-through erwartet
      force_refresh: true,
      server_context: nil
    )
    refute response.error?

    # Keine sportwart-Calls erwartet (club_cc_id nil)
    posts = @mock.calls.select { |verb, _, _, _| verb == :post }
    sportwart_calls = posts.select { |_, action, _, _| action == "sportwart-showMeldelistenList" }
    assert_equal 0, sportwart_calls.size, "Ohne club_cc_id darf kein sportwart-Call erfolgen"
  end

  test "Plan 14-G.12: Sportwart-Pfad mit unbekanntem Tournament → 0 Treffer → Fall-through zu legacy" do
    # KEINE TournamentCc-Fixture → fetch_from_sportwart_list liefert alle candidates;
    # aber Mock liefert für legacy Pfade auch 0 Treffer → diagnostic error.
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = if action == "sportwart-showMeldelistenList"
        SPORTWART_LIST_HTML
      else
        "<html><body><p>nichts</p></body></html>"
      end
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end

    response = McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 99999, # Nicht-existentes Tournament
      club_cc_id: 1010,
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      force_refresh: true,
      server_context: nil
    )
    # Ohne TournamentCc-Fixture liefert fetch_from_sportwart_list ALLE 4 candidates
    # (Disambiguation-Mode, weil kein Tournament-Name zum Matchen).
    refute response.error?, "Sportwart-Pfad mit 4 candidates sollte Disambiguation liefern"
    text = response.content.first[:text]
    assert_match(/multiple candidates/, text)
  end

  test "Plan 14-G.12: fetch_from_sportwart_list parser extrahiert meldelisteId + name + count" do
    doc = Nokogiri::HTML(SPORTWART_LIST_HTML)
    options = doc.css('select[name="meldelisteId"] option')
    assert_equal 4, options.size

    # Verifiziert dass das Parser-Regex aus dem Refactor das Format korrekt liest
    parsed = options.map do |opt|
      title_with_count = opt.text.to_s.strip
      if (m = title_with_count.match(/\A(.+?)\s+\[(\d+)\s+Meldungen\]\s*\z/))
        {meldeliste_cc_id: opt["value"].to_i, name: m[1].strip, count: m[2].to_i}
      else
        {meldeliste_cc_id: opt["value"].to_i, name: title_with_count, count: 0}
      end
    end

    assert_equal({meldeliste_cc_id: 1310, name: "NDM Endrunde Eurokegel", count: 1},
                 parsed.find { |c| c[:meldeliste_cc_id] == 1310 })
    assert_equal({meldeliste_cc_id: 1291, name: "NDM Jugend Eurokegel", count: 0},
                 parsed.find { |c| c[:meldeliste_cc_id] == 1291 },
                 "Edge-Case: kein '[N Meldungen]'-Suffix → count: 0")
  end

  # ---------------------------------------------------------------------
  # Plan 24-01 T3: Pipe-Anchor-Parser + Title-Match + with_session_recovery
  # ---------------------------------------------------------------------
  # Fixture aus heutigem live-curl gegen LSW-Endpoint mit frischer SID
  # (29969 bytes, ~40 Anchors im Pipe-Pattern, inkl. meldeliste_cc_id=1312
  # für Vorgabepokal Dreiband MB). Stub-Fixture aus cc_session_test.rb-Familie.

  def lsw_fixture_body
    File.read(Rails.root.join("test/fixtures/cc/lsw_meldelistenlist_full.html"))
  end

  def auto_logout_body
    File.read(Rails.root.join("test/fixtures/cc/auto_logout_stub.html"))
  end

  test "T3 fetch_from_cc: parst Pipe-Anchors (Plan 21-13 D-EXEC-A-Format), findet 1312" do
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = File.read(Rails.root.join("test/fixtures/cc/lsw_meldelistenlist_full.html"))
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    candidates = McpServer::Tools::LookupMeldelisteForTournament.parse_pipe_anchors(
      Nokogiri::HTML(lsw_fixture_body)
    )
    refute_empty candidates, "Pipe-Anchor-Parser muss aus live-Fixture Anchors finden"
    cc_ids = candidates.map { |c| c[:meldeliste_cc_id] }
    assert_includes cc_ids, 1312, "meldeliste_cc_id=1312 (Vorgabepokal Dreiband MB) muss gefunden werden"
    vorgabe = candidates.find { |c| c[:meldeliste_cc_id] == 1312 }
    assert_equal "Vorgabepokal Dreiband MB", vorgabe[:name]
    assert_equal "cc-live", vorgabe[:source]
  end

  test "T3 fetch_from_cc: Title-exact-Match auf TournamentCc.name liefert nur diese eine Candidate" do
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = File.read(Rails.root.join("test/fixtures/cc/lsw_meldelistenlist_full.html"))
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    # TCc-Stub: nutze Klassen-Method-Mock damit kein DB-Fixture nötig
    tcc_stub = Struct.new(:name).new("Vorgabepokal Dreiband MB")
    TournamentCc.stub :find_by, tcc_stub do
      McpServer::Tools::LookupMeldelisteForTournament.stub :effective_cc_region, "nbv" do
        candidates = McpServer::Tools::LookupMeldelisteForTournament.fetch_from_cc(
          889, fed_cc_id: 20, branch_cc_id: 10, season: "2025/2026", server_context: nil
        )
        assert_equal 1, candidates.size, "Title-Match muss aus ~40 nur 1 Candidate liefern"
        assert_equal 1312, candidates.first[:meldeliste_cc_id]
        assert_equal "Vorgabepokal Dreiband MB", candidates.first[:name]
      end
    end
  end

  test "T3 fetch_from_cc: Title-Substring-Match returnt Substring-Treffer wenn kein exact" do
    @mock.define_singleton_method(:post) do |_a, _p = {}, _o = {}|
      [Struct.new(:code, :message, :body).new("200", "OK", File.read(Rails.root.join("test/fixtures/cc/lsw_meldelistenlist_full.html"))),
       Nokogiri::HTML(File.read(Rails.root.join("test/fixtures/cc/lsw_meldelistenlist_full.html")))]
    end
    # TCc mit kürzerem Substring-Namen, der als Substring in HTML-Anchor-Title vorkommt
    tcc_stub = Struct.new(:name).new("Vorgabepokal Dreiband")  # Substring von "Vorgabepokal Dreiband MB" und auch von "1. Vorgabepokal" (nein, nur erstere)
    TournamentCc.stub :find_by, tcc_stub do
      McpServer::Tools::LookupMeldelisteForTournament.stub :effective_cc_region, "nbv" do
        candidates = McpServer::Tools::LookupMeldelisteForTournament.fetch_from_cc(
          889, fed_cc_id: 20, branch_cc_id: 10, season: "2025/2026", server_context: nil
        )
        # Substring "Vorgabepokal Dreiband" matcht "Vorgabepokal Dreiband MB" (Anchor enthält tcc-Name)
        # plus alle anderen wo Anchor-Name als Substring von tcc-Name vorkommt
        assert candidates.size >= 1, "mindestens 1 Substring-Treffer"
        assert(candidates.any? { |c| c[:meldeliste_cc_id] == 1312 })
      end
    end
  end

  test "T3 fetch_from_cc: kein TCc → alle Candidates als Disambiguation-Fallback" do
    @mock.define_singleton_method(:post) do |_a, _p = {}, _o = {}|
      [Struct.new(:code, :message, :body).new("200", "OK", File.read(Rails.root.join("test/fixtures/cc/lsw_meldelistenlist_full.html"))),
       Nokogiri::HTML(File.read(Rails.root.join("test/fixtures/cc/lsw_meldelistenlist_full.html")))]
    end
    TournamentCc.stub :find_by, nil do
      McpServer::Tools::LookupMeldelisteForTournament.stub :effective_cc_region, "nbv" do
        candidates = McpServer::Tools::LookupMeldelisteForTournament.fetch_from_cc(
          99999, fed_cc_id: 20, branch_cc_id: 10, season: "2025/2026", server_context: nil
        )
        assert candidates.size > 1, "Ohne TCc kommen ALLE Pipe-Anchors als Disambiguation-Candidates zurück"
      end
    end
  end

  # Helper: Setting.login_to_cc stubben (Module-Level), damit Re-Login keine echte CC-IO macht.
  def with_stubbed_login(returning: "FRESH_SID_32_CHARS_xxxxxxxxxxxxx", raises: nil)
    Setting.singleton_class.send(:alias_method, :_orig_login_to_cc, :login_to_cc)
    if raises
      Setting.singleton_class.send(:define_method, :login_to_cc) { raise raises }
    else
      Setting.singleton_class.send(:define_method, :login_to_cc) { returning }
    end
    yield
  ensure
    Setting.singleton_class.send(:alias_method, :login_to_cc, :_orig_login_to_cc)
    Setting.singleton_class.send(:remove_method, :_orig_login_to_cc)
  end

  test "T3 fetch_from_cc: Auto-Logout-Stub triggert Re-Login + Single-Retry → 1312 nach Recovery" do
    call_count = 0
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      call_count += 1
      body = if call_count == 1
        File.read(Rails.root.join("test/fixtures/cc/auto_logout_stub.html"))
      else
        File.read(Rails.root.join("test/fixtures/cc/lsw_meldelistenlist_full.html"))
      end
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    # NICHT mock-mode — sonst erzeugt client_for einen neuen MockClient statt _client_override.
    # Stattdessen: _client_override aktiv lassen + Setting.login_to_cc stubben + SID pre-seeden.
    prev_mock = ENV["CARAMBUS_MCP_MOCK"]
    ENV["CARAMBUS_MCP_MOCK"] = nil
    begin
      tcc_stub = Struct.new(:name).new("Vorgabepokal Dreiband MB")
      with_stubbed_login do
        TournamentCc.stub :find_by, tcc_stub do
          McpServer::Tools::LookupMeldelisteForTournament.stub :effective_cc_region, "nbv" do
            candidates = McpServer::Tools::LookupMeldelisteForTournament.fetch_from_cc(
              889, fed_cc_id: 20, branch_cc_id: 10, season: "2025/2026", server_context: nil
            )
            assert_equal 2, call_count, "Block muss zweimal aufgerufen werden (1. expired, 2. retry success)"
            assert_equal 1, candidates.size
            assert_equal 1312, candidates.first[:meldeliste_cc_id]
          end
        end
      end
    ensure
      ENV["CARAMBUS_MCP_MOCK"] = prev_mock
    end
  end

  test "T3 self.call: SessionRecoveryFailed liefert strukturierten Error statt 0 Treffer" do
    @mock.define_singleton_method(:post) do |_a, _p = {}, _o = {}|
      body = File.read(Rails.root.join("test/fixtures/cc/auto_logout_stub.html"))
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    # Auch hier non-mock-mode (sonst _client_override umgangen).
    # Block liefert beide Male Auto-Logout-Stub → with_session_recovery raises SessionRecoveryFailed
    # → self.call fängt → klare Error-Message.
    prev_mock = ENV["CARAMBUS_MCP_MOCK"]
    ENV["CARAMBUS_MCP_MOCK"] = nil
    begin
      with_stubbed_login do
        response = McpServer::Tools::LookupMeldelisteForTournament.call(
          tournament_cc_id: 889, fed_cc_id: 20, branch_cc_id: 10, season: "2025/2026",
          force_refresh: true, server_context: nil
        )
        assert response.error?
        text = response.content.first[:text]
        assert_match(/Session/i, text, "Error muss Session-Expiry-Markierung enthalten")
        assert_match(/Re-Login/i, text, "Error muss Re-Login-Hinweis enthalten")
        # Anti-Regression: kein „0 Treffer"-Stillschweigen, kein „Meldeliste nicht finden"
        refute_match(/0 Treffer/, text)
        refute_match(/Resolver konnte Meldeliste nicht finden/, text)
      end
    ensure
      ENV["CARAMBUS_MCP_MOCK"] = prev_mock
    end
  end

  # DEFER-25-4: scope-filter-Pfad muss meisterschaftsId im Payload enthalten
  test "DEFER-25-4: scope-filter-Payload enthält meisterschaftsId" do
    captured_payload = nil
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      captured_payload = post_options
      body = '<html><body><tr data-meldeliste-cc-id="1347"><td>NDM Test Cadre 35/2</td></tr></body></html>'
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end

    McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 937,
      fed_cc_id: 20, branch_cc_id: 10, season: "2025/2026",
      force_refresh: true, server_context: nil
    )

    posts = @mock.calls.select { |verb, _, _, _| verb == :post }
    assert posts.any?, "Mindestens ein POST soll erfolgt sein"
    scope_payload = posts.first[2]
    assert_equal 937, scope_payload[:meisterschaftsId], "Scope-Filter-Payload muss meisterschaftsId enthalten (DEFER-25-4)"
    assert_equal 20, scope_payload[:fedId]
    assert_equal 10, scope_payload[:branchId]
  end
end
