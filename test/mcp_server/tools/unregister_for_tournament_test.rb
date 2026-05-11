# frozen_string_literal: true

require "test_helper"

# Tests für cc_unregister_for_tournament (Plan 08-02 Mock-Implementation).
# Mock-only Scope: keine Live-CC-Calls; Live-Validation ist Plan 08-03.
#
# Sicherheitsschichten-Coverage:
#   1. armed-Default false → Test 1 (dry-run)
#   2. Mock-Mode-Default → setup nutzt _client_override mit MockClient
#   3. Rails-env-Check → Test 7 (Rails.env.production? blockiert armed:true)
#   4. Detail-Dry-Run-Echo → Test 1 (alle ID-Werte im Output)
#
# 5-Step-Chain-Coverage:
#   Test 2: armed:true ruft 5 sequentielle Calls (Pre-Read → cc_remove → Re-Render → Save → Read-Back)
#
# Pre-Validation (player must be in Meldeliste): Test 3.
# Listen-Eintrags-ID-Resolver: Test 5.

class McpServer::Tools::UnregisterForTournamentTest < ActiveSupport::TestCase
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

  # Stateful-Mock-Closure (Phase 6/7 Pattern):
  # Pre-Read liefert HTML mit player 10031 in Meldeliste; Read-Back liefert HTML ohne player.
  def with_stateful_mock(player_cc_id: 10031, listen_eintrags_id: 10413)
    # State: pre/post indicator
    post_save_phase = false
    @mock.define_singleton_method(:post) do |action, post_options = {}, opts = {}|
      @calls << [:post, action, post_options, opts]
      body = case action
      when "showCommittedMeldeliste"
        # dla=1 Mode vs firstEntry=1 Mode distinction
        if !post_save_phase
          "<html><body><tr data-player-cc-id='#{player_cc_id}' data-eintrags-id='#{listen_eintrags_id}'><td>#{player_cc_id}</td></tr></body></html>"
        else
          # Read-Back nach Save: player NICHT mehr im HTML
          "<html><body><table>(empty Meldeliste)</table></body></html>"
        end
      when "saveMeldeliste"
        post_save_phase = true
        "<html><body>SAVE OK</body></html>"
      else
        "<html><body>MOCK #{action} OK</body></html>"
      end
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
  end

  test "armed:false (default) returns Dry-Run text mit allen ID-Werten und Resolver-Output" do
    with_stateful_mock
    response = McpServer::Tools::UnregisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 10031, club_cc_id: 1010,
      server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    # Schicht 4: alle ID-Werte explizit
    assert_match(/\[DRY-RUN\] Would unregister player_cc_id=10031/, text)
    assert_match(/meldeliste_cc_id=1310/, text)
    assert_match(/fed_id=20/, text)
    assert_match(/branch_cc_id=8/, text)
    assert_match(/club_cc_id=1010/, text)
    assert_match(/season=2025\/2026/, text)
    assert_match(/Resolved Listen-Eintrags-ID: 10413/, text)
    assert_match(/Effective `a=` value: 10413/, text)
    assert_match(/Workflow: 3-Step/, text)
    assert_match(/Pass armed:true/, text)
    # Pre-Read ist gelaufen (1 Call) — Resolver/Pre-Validation; aber nicht remove/save
    posts = @mock.calls.select { |verb, _, _, _| verb == :post }
    actions = posts.map { |_, action, _, _| action }
    assert_includes actions, "showCommittedMeldeliste"
    refute_includes actions, "removePlayerFromMeldeliste"
    refute_includes actions, "saveMeldeliste"
  end

  test "armed:true Mock-Success ruft 3-Step-Chain (Pre-Read → remove → Save → Read-Back)" do
    with_stateful_mock
    response = McpServer::Tools::UnregisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 10031, club_cc_id: 1010,
      armed: true, server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    assert_match(/Unregistered player_cc_id=10031/, text)
    assert_match(/Steps completed:/, text)
    # 5-Step-Chain in genau dieser Reihenfolge
    posts = @mock.calls.select { |verb, _, _, _| verb == :post }
    actions = posts.map { |_, action, _, _| action }
    expected = %w[showCommittedMeldeliste removePlayerFromMeldeliste saveMeldeliste showCommittedMeldeliste]
    assert_equal expected, actions, "Erwarte 4-Step-Chain (Pre-Read → remove → Save → Read-Back) — got #{actions.inspect}"
    # read_back_match: true (Stateful-Mock zeigt player NICHT mehr nach save)
    assert_match(/read_back_match: true/, text)
  end

  test "Pre-Validation: error wenn player nicht in Meldeliste" do
    # Stateful-Mock zeigt player 10031 — suche nach player 88888 (nicht vorhanden)
    with_stateful_mock
    response = McpServer::Tools::UnregisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 88888, club_cc_id: 1010,
      server_context: nil
    )
    assert response.error?
    text = response.content.first[:text]
    assert_match(/Player 88888 not in Meldeliste 1310/, text)
    # Pre-Read ist gelaufen, aber kein cc_remove
    posts = @mock.calls.select { |verb, _, _, _| verb == :post }
    actions = posts.map { |_, action, _, _| action }
    assert_equal ["showCommittedMeldeliste"], actions
  end

  test "armed:false (default) erreicht client.post nur für Pre-Read (kein cc_remove/save)" do
    with_stateful_mock
    McpServer::Tools::UnregisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 10031, club_cc_id: 1010,
      server_context: nil
    )
    # Schicht 1: armed=false MUSS keine destruktiven Posts erzeugen
    posts = @mock.calls.select { |verb, _, _, _| verb == :post }
    actions = posts.map { |_, action, _, _| action }
    assert_equal ["showCommittedMeldeliste"], actions,
      "Dry-Run darf nur Pre-Read aufrufen, NICHT removePlayerFromMeldeliste/saveMeldeliste"
  end

  test "Listen-Eintrags-ID-Resolver parst Mock-HTML5 data-eintrags-id korrekt" do
    doc = Nokogiri::HTML(<<~HTML)
      <html><body>
        <tr data-player-cc-id="10031" data-eintrags-id="10413"><td>Player A</td></tr>
        <tr data-player-cc-id="10032" data-eintrags-id="10414"><td>Player B</td></tr>
      </body></html>
    HTML
    assert_equal 10413, McpServer::Tools::UnregisterForTournament.resolve_listen_eintrags_id(doc, 10031)
    assert_equal 10414, McpServer::Tools::UnregisterForTournament.resolve_listen_eintrags_id(doc, 10032)
    assert_nil McpServer::Tools::UnregisterForTournament.resolve_listen_eintrags_id(doc, 99999)
  end

  test "Resolver-Fallback: player_in_meldeliste? Substring-Match bei fehlendem data-Attribut" do
    # Real-CC-Format ohne data-Attribute: nur Player-ID als Text in TD-Element
    doc = Nokogiri::HTML(<<~HTML)
      <html><body><table><tr><td>10031</td><td>Player X</td></tr></table></body></html>
    HTML
    # Resolver liefert nil (kein data-Attribut)
    assert_nil McpServer::Tools::UnregisterForTournament.resolve_listen_eintrags_id(doc, 10031)
    # Aber Substring-Match findet Player → Tool nutzt player_cc_id als Fallback
    assert McpServer::Tools::UnregisterForTournament.player_in_meldeliste?(doc, 10031)
    refute McpServer::Tools::UnregisterForTournament.player_in_meldeliste?(doc, 99999)
  end

  test "armed:true rejects in Rails.env.production?" do
    Rails.env.stub :production?, true do
      response = McpServer::Tools::UnregisterForTournament.call(
        fed_id: 20, branch_cc_id: 8, season: "2025/2026",
        meldeliste_cc_id: 1310, player_cc_id: 10031, club_cc_id: 1010,
        armed: true, server_context: nil
      )
      assert response.error?
      text = response.content.first[:text]
      assert_match(/Live-CC writes are blocked in Rails production env/, text)
    end
    # MockClient wurde NICHT aufgerufen — Schicht 3 fail-fast
    assert @mock.calls.empty?, "Production-blocked Tool darf MockClient nicht aufrufen, aber #{@mock.calls.inspect}"
  end

  test "Required-Parameter-Validation: alle 5 Pflicht-Felder müssen vorhanden sein" do
    response = McpServer::Tools::UnregisterForTournament.call(
      # fehlend: alles außer fed_id
      fed_id: 20, server_context: nil
    )
    assert response.error?
    text = response.content.first[:text]
    assert_match(/Missing required parameter/, text)
    # MockClient wurde nicht aufgerufen
    assert @mock.calls.empty?
  end

  test "read_back:false skippt Read-Back-Step und liefert read_back_match: :skipped" do
    with_stateful_mock
    response = McpServer::Tools::UnregisterForTournament.call(
      fed_id: 20, branch_cc_id: 8, season: "2025/2026",
      meldeliste_cc_id: 1310, player_cc_id: 10031, club_cc_id: 1010,
      armed: true, read_back: false, server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    assert_match(/read_back_match: skipped/, text)
    # 3 Steps statt 4 (Pre-Read + Remove + Save; KEIN Read-Back)
    posts = @mock.calls.select { |verb, _, _, _| verb == :post }
    assert_equal 3, posts.size, "Mit read_back:false erwartet 3 Posts, got #{posts.size}"
  end
end
