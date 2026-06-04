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

  # Mock-HTML fuer showTeilnehmerliste.php — REAL-FORMAT aus User-Browser-Capture (DFP SU 2026-06-02).
  # Plan 25-01 T3b-Hotfix: cc_id ist im title-Attribut des showTeilnehmer.php-Links eingebettet,
  # nicht in einer eigenen <td>-Cell. Test-HTML MUSS dieses Live-Format spiegeln (kein circular validation).
  def build_show_teilnehmerliste_html(teilnehmer_options:)
    rows = teilnehmer_options.each_with_index.map do |(cc_id, label), idx|
      last_first = label.split(" (").first.to_s
      last_name, first_name = last_first.split(", ", 2)
      <<~ROW
        <tr class="odd">
          <td class="bb1" align="center">#{idx + 1}</td>
          <td class="bb1"><a href="showTeilnehmer.php?p=20-7-*-2025/2026-*--859-#{cc_id}&amp;" title="#{last_name}, #{first_name} (#{cc_id})" class="cc_bluelink">#{last_name}</a></td>
          <td class="bb1">#{first_name}</td>
          <td class="bb1" align="center">#{cc_id}</td>
          <td class="bb1">BC Wedel</td>
          <td class="bb1" align="center">1010</td>
          <td class="bb1">fristgerecht gemeldet</td>
        </tr>
      ROW
    end.join
    <<~HTML
      <html><body>
      <table cellspacing="0" cellpadding="8" width="100%"><tbody>
      <tr><th class="bb1" colspan="16">TEILNEHMERLISTE</th></tr>
      <tr><th class="colored">#{teilnehmer_options.size}</th><th class="colored" align="left">NACHNAME</th><th class="colored" align="left">VORNAME</th><th class="colored">PASS-NR.</th><th class="colored" align="left">VEREIN</th><th class="colored">VNR.</th><th class="colored" align="left">STATUS</th></tr>
      #{rows}
      </tbody></table>
      </body></html>
    HTML
  end

  # Plan 25-01 T3b-QuoteFix Regression-Schutz (2026-06-02): CC sendet single quotes statt
  # double quotes (Memory Plan-14-G.13 Bug #3). Live-Capture: <a ... title='X (10165)' class='cc_bluelink'>.
  # Test mit echtem single-quote-Format um sicherzustellen dass Regex beide akzeptiert.
  test "T3b-QuoteFix: parser akzeptiert single-quoted HTML (Live-CC-Format)" do
    body = <<~HTML
      <html><body><table><tbody>
      <tr><td><a href='showTeilnehmer.php?p=20-7-*-2025/2026-*--859-10165&amp;' title='Ben Ghaffar, Ramzi (10165)' class='cc_bluelink'>Ben Ghaffar</a></td></tr>
      <tr><td><a href='showTeilnehmer.php?p=20-7-*-2025/2026-*--859-10761&amp;' title='Einsiedler, Janni (10761)' class='cc_bluelink'>Einsiedler</a></td></tr>
      <tr><td><a href='showTeilnehmer.php?p=20-7-*-2025/2026-*--859-11353&amp;' title='Hepp, Neele (11353)' class='cc_bluelink'>Hepp</a></td></tr>
      </tbody></table></body></html>
    HTML
    mock = McpServer::Tools::MockClient.new
    mock.define_singleton_method(:get) { |_action, _params, _opts| [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)] }
    mock.define_singleton_method(:post) { |_action, _params, _opts| [Struct.new(:code, :message, :body).new("200", "OK", "<html></html>"), Nokogiri::HTML("<html></html>")] }
    McpServer::CcSession._client_override = mock

    response = McpServer::Tools::LookupTeilnehmerliste.call(
      tournament_cc_id: 859, fed_cc_id: 20, branch_cc_id: 7, season: "2025/2026"
    )
    refute response.error?, "expected non-error; got: #{response.content.first[:text]}"
    body_json = JSON.parse(response.content.first[:text])
    assert_equal "finalized", body_json["phase"], "single-quote Regex muss matchen"
    assert_equal 3, body_json["counts"]["teilnehmer"]
    assert_equal [10165, 10761, 11353], body_json["current_teilnehmer"].map { |t| t["cc_id"] }
    assert_equal "Ben Ghaffar, Ramzi", body_json["current_teilnehmer"].first["label"]
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

  # DEFER-25-9 Regression-Schutz: branch_cc_id-Default muss branch_cc.cc_id (admin-cc-id) liefern,
  # nicht TournamentCc.branch_cc_id (Rails-FK auf branch_ccs.id, andere Zahl).
  test "DEFER-25-9: branchId Default nutzt branch_cc.cc_id (admin-cc-id), nicht Rails-FK" do
    region_cc_stub = Struct.new(:cc_id).new(20)
    branch_cc_stub = Struct.new(:cc_id, :region_cc).new(7, region_cc_stub)
    tournament_cc_stub = Struct.new(:branch_cc, :branch_cc_id, :season).new(branch_cc_stub, 3, "2025/2026")

    captured_p_param = nil
    show_body = "<html><body><table></table></body></html>"
    mock = McpServer::Tools::MockClient.new
    mock.define_singleton_method(:get) do |action, params, opts|
      @calls << [:get, action, params, opts]
      captured_p_param = params[:p] if action == "showTeilnehmerliste"
      [Struct.new(:code, :message, :body).new("200", "OK", show_body), Nokogiri::HTML(show_body)]
    end
    mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      [Struct.new(:code, :message, :body).new("200", "OK", "<html></html>"), Nokogiri::HTML("<html></html>")]
    end
    McpServer::CcSession._client_override = mock

    TournamentCc.stub(:find_by, tournament_cc_stub) do
      McpServer::Tools::LookupTeilnehmerliste.call(
        tournament_cc_id: 859,
        fed_cc_id: 20,
        season: "2025/2026"
        # kein branch_cc_id — Default soll branch_cc.cc_id=7 liefern, nicht Rails-FK=3
      )
    end

    assert_not_nil captured_p_param, "GET showTeilnehmerliste sollte aufgerufen worden sein"
    # p_param = "fedId-branchId-*-season-*--tournament_cc_id-3"
    assert_match(/\A20-7-/, captured_p_param, "branchId muss branch_cc.cc_id=7 sein, nicht Rails-FK=3")
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
