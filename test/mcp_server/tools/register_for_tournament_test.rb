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
    # Schicht 4: alle ID-Werte explizit im Dry-Run-Output
    assert_match(/\[DRY-RUN\] Would register player_cc_id=99999/, text)
    assert_match(/meldeliste_cc_id=1310/, text)
    assert_match(/fed_id=20/, text)
    assert_match(/branch_cc_id=8/, text)
    assert_match(/club_cc_id=1010/, text)
    assert_match(/season=2025\/2026/, text)
    assert_match(/Workflow: 2-Step/, text)
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
    assert_match(/Registered player_cc_id=99999 into meldeliste_cc_id=1310/, text)
    # 2-Step-Workflow + Verifikation: exakt 3 POSTs in dieser Reihenfolge
    posts = @mock.calls.select { |verb, _, _, opts| verb == :post && opts[:armed] }
    actions = posts.map { |_, action, _, _| action }
    assert_equal %w[addPlayerToMeldeliste saveMeldeliste showCommittedMeldeliste], actions,
      "Erwarte 3 POSTs in genau dieser Reihenfolge — got #{actions.inspect}"
    # Default-MockClient liefert body="" → verified=false (kein Marker im Mock-HTML)
    assert_match(/verified_in_committed_list: false/, text)
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
    assert_match(/Missing required parameter/i, response.content.first[:text])
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
      raise RuntimeError, "simulated network failure"
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

  test "Schicht 3: armed:true in Rails production env wird mit error blockiert" do
    Rails.env.stub(:production?, true) do
      response = McpServer::Tools::RegisterForTournament.call(
        fed_id: 20, branch_cc_id: 8, season: "2025/2026",
        meldeliste_cc_id: 1310, player_cc_id: 99999, club_cc_id: 1010,
        armed: true, server_context: nil
      )
      assert response.error?
      assert_match(/blocked in Rails production/, response.content.first[:text])
    end
    # MockClient wurde NICHT aufgerufen — Schicht 3 fail-fast
    assert @mock.calls.empty?, "Production-blocked Tool darf MockClient nicht aufrufen, aber #{@mock.calls.inspect}"
  end
end
