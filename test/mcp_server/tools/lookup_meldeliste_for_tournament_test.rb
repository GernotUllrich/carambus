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
    # Plan 14-02.3 / F-6: Sportwart-Vokabular im Error-Message.
    assert_match(/keine Meldeliste.*LSW kontaktieren/i, text)
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
    # 1. POST: scope-filter payload
    payload_1 = posts[0][2]
    assert_equal 20, payload_1[:fedId]
    refute payload_1.key?(:meisterschaftsId)
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
    # Plan 14-02.3 / F-6: Sportwart-Vokabular leadingl; geprüfte Pfade als technische
    # Diagnose-Sektion erhalten bleibt (für Audit-Trail / Bug-Reports).
    assert_match(/keine Meldeliste.*LSW kontaktieren/i, text)
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
    refute payload.key?(:meisterschaftsId), "Scope-Filter-Pfad darf KEIN meisterschaftsId-Key haben"
  end

  test "Plan 09-02 T-Scope-Partial: nur fed_cc_id + branch_cc_id → partial Scope-Filter-Payload" do
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = '<html><body><tr data-meldeliste-cc-id="1310"><td>Result</td></tr></body></html>'
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 890, fed_cc_id: 20, branch_cc_id: 8,
      force_refresh: true, server_context: nil
    )
    # Plan 14-02.3 / F-5: filter auf erste POST-Call (GET editMeldelisteCheck ist Pfad-1-Probe)
    payload = @mock.calls.find { |verb, _, _, _| verb == :post }[2]
    assert_equal 20, payload[:fedId]
    assert_equal 8, payload[:branchId]
    refute payload.key?(:season), "Partial: season nicht gesetzt → kein Key"
    refute payload.key?(:catId), "Partial: cat_id nicht gesetzt → kein Key"
    refute payload.key?(:meisterschaftsId), "Partial Scope-Filter darf KEIN meisterschaftsId-Key haben"
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

  test "Plan 09-02 T-Backwards-Compat: ohne Scope-Filter → meisterschaftsId-Pfad (Plan 08-02 default)" do
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = '<html><body><tr data-meldeliste-cc-id="1310"><td>Result</td></tr></body></html>'
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    McpServer::Tools::LookupMeldelisteForTournament.call(
      tournament_cc_id: 890, force_refresh: true, server_context: nil
    )
    # Plan 14-02.3 / F-5: filter auf erste POST-Call (GET editMeldelisteCheck ist Pfad-1-Probe)
    payload = @mock.calls.find { |verb, _, _, _| verb == :post }[2]
    assert_equal 890, payload[:meisterschaftsId], "Backwards-Compat: meisterschaftsId muss gesendet werden"
    refute payload.key?(:fedId), "Backwards-Compat darf KEIN Scope-Filter-Key haben"
    refute payload.key?(:branchId)
    refute payload.key?(:season)
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
end
