# frozen_string_literal: true
require "test_helper"

# Tests für cc_register_for_tournament (Plan 04-02 Mock-Implementation).
# Mock-only Scope: keine Live-CC-Calls; Live-Validation ist Plan 04-03.
#
# Sicherheitsschichten-Coverage:
#   1. armed-Default false → Test 1 (dry-run)
#   2. Mock-Mode-Default → setup nutzt _client_override mit MockClient
#   3. Rails-env-Check → Test 7 (Rails.env.production? blockiert armed:true)
#   4. Detail-Dry-Run-Echo → Test 1 (alle ID-Werte im Output)
#
# Konsistenz-Check Option A (Existenz auf PlayerRanking) → Test 6 (Warnung-Pfad).
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
      fed_id: 20, branch_id: 10, season: "2025/2026",
      tournament_cc_id: 12345, player_cc_id: 99999,
      server_context: nil
    )
    refute response.error?
    text = response.content.first[:text]
    # Schicht 4: alle ID-Werte explizit im Dry-Run-Output
    assert_match(/\[DRY-RUN\] Would register player_cc_id=99999/, text)
    assert_match(/tournament_cc_id=12345/, text)
    assert_match(/fed_id=20/, text)
    assert_match(/branch_id=10/, text)
    assert_match(/season=2025\/2026/, text)
    assert_match(/Pass armed:true to actually perform/, text)
    # Schicht 1: armed=false erreicht client.post NIE (Tool returned VOR POST)
    assert @mock.calls.empty?, "Dry-run darf MockClient nicht aufrufen, aber #{@mock.calls.inspect}"
  end

  test "armed:true Mock-Success returns 'Registered' text + ruft MockClient mit POST auf" do
    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_id: 10, season: "2025/2026",
      tournament_cc_id: 12345, player_cc_id: 99999, armed: true,
      server_context: nil
    )
    refute response.error?
    assert_match(/Registered player_cc_id=99999/, response.content.first[:text])
    # MockClient wurde mit POST + armed=true aufgerufen
    matching = @mock.calls.select { |verb, action, _, opts| verb == :post && action == "registerForTournament" && opts[:armed] }
    assert matching.any?, "Erwarte ≥1 POST registerForTournament mit armed:true, got #{@mock.calls.inspect}"
  end

  test "Validation: fehlendes player_cc_id gibt error mit Parameter-Namen zurück" do
    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_id: 10, season: "2025/2026", tournament_cc_id: 12345,
      server_context: nil
    )
    assert response.error?
    assert_match(/Missing required parameter/i, response.content.first[:text])
    assert_match(/player_cc_id/, response.content.first[:text])
  end

  test "Permission-Error: error-div in CC-Response wird als MCP-Error zurückgegeben" do
    error_doc = Nokogiri::HTML('<html><body><div class="error">Permission denied: club role required</div></body></html>')
    @mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      [Struct.new(:code, :message, :body).new("200", "OK", ""), error_doc]
    end

    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_id: 10, season: "2025/2026",
      tournament_cc_id: 12345, player_cc_id: 99999, armed: true,
      server_context: nil
    )
    assert response.error?
    assert_match(/CC rejected.*Permission denied/, response.content.first[:text])
  end

  test "Defensive: Exception in client.post gibt error envelope ohne stacktrace zurück" do
    @mock.define_singleton_method(:post) do |*_|
      raise RuntimeError, "simulated network failure"
    end

    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_id: 10, season: "2025/2026",
      tournament_cc_id: 12345, player_cc_id: 99999, armed: true,
      server_context: nil
    )
    assert response.error?
    assert_match(/Tool exception: RuntimeError/, response.content.first[:text])
    refute_match(/backtrace|line \d+/i, response.content.first[:text])
  end

  test "Konsistenz-Check: Player nicht in Carambus-DB erzeugt 'übersprungen'-Status im Output" do
    # cc_id=99999999 ist garantiert nicht in DB → Player.find_by liefert nil
    response = McpServer::Tools::RegisterForTournament.call(
      fed_id: 20, branch_id: 10, season: "2025/2026",
      tournament_cc_id: 12345, player_cc_id: 99999999,
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
        fed_id: 20, branch_id: 10, season: "2025/2026",
        tournament_cc_id: 12345, player_cc_id: 99999, armed: true,
        server_context: nil
      )
      assert response.error?
      assert_match(/blocked in Rails production/, response.content.first[:text])
    end
    # MockClient wurde NICHT aufgerufen — Schicht 3 fail-fast
    assert @mock.calls.empty?, "Production-blocked Tool darf MockClient nicht aufrufen, aber #{@mock.calls.inspect}"
  end
end
