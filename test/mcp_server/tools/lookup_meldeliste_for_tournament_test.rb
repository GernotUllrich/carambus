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

  test "0 Treffer: Mock liefert leeren HTML → error" do
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
    assert_match(/Tournament 99999 has no Meldelisten/, text)
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
end
