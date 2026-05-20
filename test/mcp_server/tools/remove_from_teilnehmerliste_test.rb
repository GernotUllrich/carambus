# frozen_string_literal: true

require "test_helper"

# Tests für cc_remove_from_teilnehmerliste (Plan 07-04 Inline-Patch — D-7-8).
# Mock-only Scope analog assign_player_to_teilnehmerliste_test.rb.

class McpServer::Tools::RemoveFromTeilnehmerlisteTest < ActiveSupport::TestCase
  # Reuse the build_check_html-Helper from assign-test (gleicher HTML-Struktur).
  def self.build_check_html(teilnehmer_options: [], meldung_options: [], tournament_name: "MOCK NDM Endrunde Eurokegel")
    McpServer::Tools::AssignPlayerToTeilnehmerlisteTest.build_check_html(
      teilnehmer_options: teilnehmer_options,
      meldung_options: meldung_options,
      tournament_name: tournament_name
    )
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

  # Stateful MockClient für Remove: simuliert State-Transition (Spieler verschwindet aus Teilnehmerliste).
  def build_stateful_mock(initial_teilnehmer: [[11683, "Nachtmann, Georg (11683)"], [10024, "Schröder, Hans-Jörg (10024)"]],
    initial_meldung: [], tournament_name: "MOCK NDM Endrunde Eurokegel")
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
      when "removePlayer"
        # State-Mutation: remove teilnehmerId from current_teilnehmer
        removed_id = params[:teilnehmerId].to_i
        removed = current_teilnehmer.find { |id, _| id == removed_id }
        current_teilnehmer.delete(removed) if removed
        [Struct.new(:code, :message, :body).new("200", "OK", ""),
          Nokogiri::HTML("<html><body>MOCK POST removePlayer OK</body></html>")]
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

  test "armed:false (default) returns Detail-Echo ohne CC-Mutation-Call" do
    response = McpServer::Tools::RemoveFromTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_id: 11683,
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      server_context: nil
    )
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    text = response.content.first[:text]
    assert_match(/\[DRY-RUN\] Would remove player_cc_id=11683/, text)
    assert_match(/Nachtmann/, text)
    assert_match(/teilnehmerliste_count_before: 2/, text)
    assert_match(/teilnehmerliste_count_after:  1/, text)
    # Schicht 1: kein Write-Call
    write_calls = @mock.calls.select { |verb, action, _, _| verb == :post && %w[removePlayer editTeilnehmerlisteSave].include?(action) }
    assert write_calls.empty?, "Dry-Run darf removePlayer/Save NICHT aufrufen"
  end

  test "armed:true ruft Pre-Read → removePlayer → Save → Read-Back in genau dieser Reihenfolge" do
    response = McpServer::Tools::RemoveFromTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_id: 11683,
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      armed: true, server_context: nil
    )
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    text = response.content.first[:text]
    assert_match(/Removed player_cc_id=11683.*tournament_cc_id=890/, text)
    assert_match(/teilnehmerliste_count_after:  1/, text)
    assert_match(/read_back_match: true/, text)
    actions = @mock.calls.select { |verb, _, _, _| verb == :post }.map { |_, a, _, _| a }
    assert_equal ["editTeilnehmerlisteCheck", "removePlayer", "editTeilnehmerlisteCheck", "editTeilnehmerlisteSave", "editTeilnehmerlisteCheck"], actions,
      "Erwarte Pre-Read → removePlayer → Re-Render → Save → Read-Back (Plan 07-04 Risk A) — got #{actions.inspect}"
  end

  test "removePlayer-Payload enthält teilnehmerId Single (KEIN Array) + 9-Felder-Base" do
    McpServer::Tools::RemoveFromTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_id: 11683,
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      armed: true, server_context: nil
    )
    rm_call = @mock.calls.find { |verb, action, _, _| verb == :post && action == "removePlayer" }
    refute_nil rm_call, "removePlayer muss aufgerufen worden sein"
    _, _, params, _ = rm_call
    # Plan 07-04 Inline-Patch v2: zusätzlich :referer (Real-Client setzt als HTTP-Header, nicht im Body)
    required_keys = %i[fedId branchId disciplinId catId season meisterTypeId meisterschaftsId sortedBy firstEntry teilnehmerId]
    missing_keys = required_keys - params.keys
    assert_empty missing_keys, "Remove-Payload fehlen Felder: #{missing_keys.inspect}; got #{params.keys.sort.inspect}"
    assert_equal 11683, params[:teilnehmerId], "teilnehmerId muss Single Integer sein (NICHT Array)"
  end

  test "Validation: player_cc_id NICHT in Teilnehmerliste → ToolError" do
    response = McpServer::Tools::RemoveFromTeilnehmerliste.call(
      tournament_cc_id: 890, player_cc_id: 99999, # NICHT in Teilnehmerliste
      fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026",
      armed: true, server_context: nil
    )
    assert response.error?
    text = response.content.first[:text]
    assert_match(/Player 99999 not in Teilnehmerliste/, text)
    assert_match(/cc_assign_player_to_teilnehmerliste/, text)
    # Kein removePlayer-Call
    rm_calls = @mock.calls.select { |verb, action, _, _| verb == :post && action == "removePlayer" }
    assert rm_calls.empty?, "Validation-Fail darf removePlayer NICHT auslösen"
  end

  # Plan 10-05.1 Task 1 (D-10-04-B Pivot): Phase-4-Schicht-3 (Production-Block) DEPRECATED.
  # Vorheriger Test entfernt. Pre-Validation-First-Pattern (Task 4) macht Tool zum Sicherheitsnetz.

  test "Validation: fehlendes player_cc_id → Missing-required-error" do
    response = McpServer::Tools::RemoveFromTeilnehmerliste.call(
      tournament_cc_id: 890, server_context: nil
    )
    assert response.error?
    assert_match(/Missing required parameter/i, response.content.first[:text])
    assert_match(/player_cc_id/, response.content.first[:text])
  end

  test "Tool ist als cc_remove_from_teilnehmerliste registriert" do
    tools = McpServer::Server.collect_tools.map { |t| t.respond_to?(:tool_name) ? t.tool_name : nil }.compact
    assert_includes tools, "cc_remove_from_teilnehmerliste"
  end
end
