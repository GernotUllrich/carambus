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
    # Plan 10-02 Task 1 (Befund #5 Fix): Diagnostic Error-Message statt False-Claim
    assert_match(/Could not auto-resolve meldeliste_cc_id for tournament_cc_id=99999/, text)
    assert_match(/attempted: meisterschaftsId=99999/, text)
    assert_match(/does NOT necessarily mean no meldeliste exists/, text)
    assert_match(/Workaround: pass meldeliste_cc_id directly/, text)
    # Anti-Regression: alte False-Claim darf NICHT mehr im Output sein
    refute_match(/has no Meldelisten/, text)
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
    assert_equal 2, @mock.calls.size, "Retry-Fallback muss 2. Live-CC-Call ausgelöst haben"
    # 1. Call: scope-filter payload
    payload_1 = @mock.calls[0][2]
    assert_equal 20, payload_1[:fedId]
    refute payload_1.key?(:meisterschaftsId)
    # 2. Call: meisterschaftsId fallback payload
    payload_2 = @mock.calls[1][2]
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
    assert_match(/attempted: scope-filter/, text)
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
    payload = @mock.calls.first[2]
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
    payload = @mock.calls.first[2]
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
    payload = @mock.calls.first[2]
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
    payload = @mock.calls.first[2]
    assert_equal 20, payload[:fedId]
    assert_equal "30", payload[:disciplinId]
  end
end
