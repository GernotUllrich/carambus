# frozen_string_literal: true

require "test_helper"
require_relative "assign_player_to_teilnehmerliste_test"

# Plan 25-01 T3a Spike (2026-06-02): Tests fuer die echte live_lookup-Implementation.
# Vorher: 3 Tests gegen Status-String-Stub. Jetzt: 7 Tests gegen pre_read_teilnehmerliste-Parsing.
# Wiederverwendet build_check_html-Helper aus AssignPlayerToTeilnehmerlisteTest (DRY-Mock-Pattern).

class McpServer::Tools::LookupTeilnehmerlisteTest < ActiveSupport::TestCase
  setup do
    # NICHT ENV["CARAMBUS_MCP_MOCK"]="1" setzen — das wuerde cc_session.client_for
    # zu MockClient.new (frisch, ohne unsere Stubs) forcen statt _client_override zu nutzen.
    # AssignPlayerToTeilnehmerlisteTest-Pattern: nur _client_override + reset!.
    McpServer::CcSession.reset!
    McpServer::CcSession.session_id = "TEST_SESSION_ID"
    McpServer::CcSession.session_started_at = Time.now
  end

  teardown do
    McpServer::CcSession._client_override = nil
    McpServer::CcSession.reset!
  end

  # Plan 25-01 T3b: zwei separate Mocks fuer die zwei Read-Pfade.
  # - editTeilnehmerlisteCheck (POST) → Edit-Buffer-View, liefert tournament_name + available_in_meldeliste
  # - showTeilnehmerliste (GET) → persistierte DB-View, liefert current_teilnehmer (Regex-Pattern <td align="center">{cc_id}</td>)
  def build_mock(teilnehmer:, meldung:, tournament_name:)
    edit_check_body = McpServer::Tools::AssignPlayerToTeilnehmerlisteTest.build_check_html(
      teilnehmer_options: teilnehmer,
      meldung_options: meldung,
      tournament_name: tournament_name
    )
    show_teilnehmer_body = build_show_teilnehmerliste_html(teilnehmer_options: teilnehmer)
    mock = McpServer::Tools::MockClient.new
    mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      # editTeilnehmerlisteCheck wird via POST gepollt
      [Struct.new(:code, :message, :body).new("200", "OK", edit_check_body), Nokogiri::HTML(edit_check_body)]
    end
    mock.define_singleton_method(:get) do |action, params, opts|
      @calls << [:get, action, params, opts]
      [Struct.new(:code, :message, :body).new("200", "OK", show_teilnehmer_body), Nokogiri::HTML(show_teilnehmer_body)]
    end
    McpServer::CcSession._client_override = mock
    mock
  end

  # Mock-HTML fuer showTeilnehmerliste.php — Tabellen-Format mit Player-cc_id in <td align="center">.
  # Format aus User-Browser-Snapshot 2026-06-02 (NDM Test Cadre 35/2).
  def build_show_teilnehmerliste_html(teilnehmer_options:)
    rows = teilnehmer_options.map do |cc_id, label|
      # Label-Format aus Test: "Hassendorf, Maja (42)" → Last="Hassendorf", First="Maja"
      last_first = label.split(" (").first.to_s
      last_name, first_name = last_first.split(", ", 2)
      <<~ROW
        <tr>
          <td>1</td>
          <td>#{last_name}</td>
          <td>#{first_name}</td>
          <td align="center">#{cc_id}</td>
          <td>BC Wedel</td>
          <td>1010</td>
          <td>fristgerecht gemeldet</td>
        </tr>
      ROW
    end.join
    <<~HTML
      <html><body>
      <h1>Teilnehmerliste</h1>
      <table>
        <tr><th>#</th><th>Nachname</th><th>Vorname</th><th>Pass-Nr.</th><th>Verein</th><th>VNr.</th><th>Status</th></tr>
        #{rows}
      </table>
      </body></html>
    HTML
  end

  test "Smoke-Befund DFP SU: 3 Teilnehmer + 0 Meldung -> phase=finalized" do
    build_mock(
      teilnehmer: [[42, "Hassendorf, Maja (42)"], [43, "Lange, Hendrik (43)"], [44, "Wendt, Sebastian (44)"]],
      meldung: [],
      tournament_name: "Doppel-Fun-Pokal Snooker"
    )
    response = McpServer::Tools::LookupTeilnehmerliste.call(
      tournament_cc_id: 859, fed_cc_id: 20, branch_cc_id: 7, season: "2025/2026"
    )
    refute response.error?, "expected non-error; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])
    assert_equal "Doppel-Fun-Pokal Snooker", body["tournament_name"]
    assert_equal "finalized", body["phase"]
    assert_equal 3, body["counts"]["teilnehmer"]
    assert_equal 0, body["counts"]["meldung_open"]
    assert_equal 3, body["current_teilnehmer"].size
    assert_equal 42, body["current_teilnehmer"].first["cc_id"]
    # Plan 25-01 T3b: Label kommt aus showTeilnehmerliste.php-Table-Row (Last+First), nicht aus Option-Text.
    assert_equal "Hassendorf, Maja", body["current_teilnehmer"].first["label"]
  end

  test "phase=open: Meldeliste voll, Teilnehmerliste leer" do
    build_mock(
      teilnehmer: [],
      meldung: [[11683, "Nachtmann, Georg (11683)"], [10024, "Schroeder, Hans-Joerg (10024)"]],
      tournament_name: "MOCK NDM Endrunde Eurokegel"
    )
    response = McpServer::Tools::LookupTeilnehmerliste.call(
      tournament_cc_id: 890, fed_cc_id: 20, branch_cc_id: 8, season: "2025/2026"
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_equal "open", body["phase"]
    assert_equal 0, body["counts"]["teilnehmer"]
    assert_equal 2, body["counts"]["meldung_open"]
  end

  test "phase=partial: gemischt" do
    build_mock(
      teilnehmer: [[42, "A (42)"]],
      meldung: [[43, "B (43)"], [44, "C (44)"]],
      tournament_name: "MIXED"
    )
    response = McpServer::Tools::LookupTeilnehmerliste.call(
      tournament_cc_id: 891, fed_cc_id: 20, branch_cc_id: 7, season: "2025/2026"
    )
    body = JSON.parse(response.content.first[:text])
    assert_equal "partial", body["phase"]
  end

  test "phase=empty: beide leer" do
    build_mock(teilnehmer: [], meldung: [], tournament_name: "EMPTY")
    response = McpServer::Tools::LookupTeilnehmerliste.call(
      tournament_cc_id: 892, fed_cc_id: 20, branch_cc_id: 7, season: "2025/2026"
    )
    body = JSON.parse(response.content.first[:text])
    assert_equal "empty", body["phase"]
  end

  test "missing tournament_cc_id ODER tournament_id liefert klare Fehler-Message" do
    response = McpServer::Tools::LookupTeilnehmerliste.call
    assert response.error?
    assert_match(/tournament_cc_id|tournament_id/i, response.content.first[:text])
  end

  test "fehlender scope (fed/branch/season ohne DB-Mirror) liefert Sportwart-Hinweis mit admin-cc-id-Tabelle" do
    response = McpServer::Tools::LookupTeilnehmerliste.call(tournament_cc_id: 999_999_999)
    assert response.error?
    assert_match(/Scope-Filter unvollstaendig/, response.content.first[:text])
    assert_match(/8=Kegel.*7=Snooker.*10=Karambol/, response.content.first[:text])
  end

  test "compute_phase Helper-Logik" do
    klass = McpServer::Tools::LookupTeilnehmerliste
    assert_equal "empty", klass.compute_phase(0, 0)
    assert_equal "open", klass.compute_phase(0, 5)
    assert_equal "finalized", klass.compute_phase(3, 0)
    assert_equal "partial", klass.compute_phase(2, 1)
  end
end
