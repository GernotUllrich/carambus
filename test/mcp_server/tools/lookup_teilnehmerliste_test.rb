# frozen_string_literal: true

require "test_helper"

# Plan 25-01 T3a Spike (2026-06-02): Live-Implementation-Tests.
# Plan 31-01 (2026-06-10): Mocks auf stabile Tab-2/Tab-3-Reads umgestellt.
# Kein editTeilnehmerlisteCheck-POST mehr — cc_lookup_teilnehmerliste macht nur GETs.
# Tab 3 (p endet auf -3) → akkreditierte Teilnehmer (current_teilnehmer)
# Tab 2 (p endet auf -2) → alle Registrierten; Differenz zu Tab 3 = available_in_meldeliste

class McpServer::Tools::LookupTeilnehmerlisteTest < ActiveSupport::TestCase
  setup do
    # AssignPlayerToTeilnehmerlisteTest-Pattern: nur _client_override + reset!.
    McpServer::CcSession.reset!
    McpServer::CcSession.session_id = "TEST_SESSION_ID"
    McpServer::CcSession.session_started_at = Time.now
  end

  teardown do
    McpServer::CcSession._client_override = nil
    McpServer::CcSession.reset!
  end

  # Plan 33-fix (2026-06-10): GET-Dispatch nach Action.
  #   - showTeilnehmerliste (Tab-3, p endet -3) → akkreditierte Teilnehmer (cc_bluelink-Format)
  #   - meisterschaft-showMeldeliste (p endet -2) → ALLE Meldungen (showMeldeliste.php bb1-Format)
  # available_in_meldeliste = Meldeliste(alle) minus Teilnehmer.
  def build_mock(teilnehmer:, meldung:)
    teilnehmer_body = build_teilnehmer_html(players: teilnehmer)
    meldeliste_body = build_meldeliste_html(players: teilnehmer + meldung)
    ok = Struct.new(:code, :message, :body)
    mock = McpServer::Tools::MockClient.new
    mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      [ok.new("200", "OK", "<html></html>"), Nokogiri::HTML("<html></html>")]
    end
    mock.define_singleton_method(:get) do |action, params, opts|
      @calls << [:get, action, params, opts]
      body = (action == "meisterschaft-showMeldeliste") ? meldeliste_body : teilnehmer_body
      [ok.new("200", "OK", body), Nokogiri::HTML(body)]
    end
    McpServer::CcSession._client_override = mock
    mock
  end

  # HTML fuer showTeilnehmerliste.php Tab-3 (Teilnehmerliste) — cc_bluelink title-Format.
  def build_teilnehmer_html(players:)
    rows = players.each_with_index.map do |(cc_id, label), idx|
      last_first = label.split(" (").first.to_s
      last_name, first_name = last_first.split(", ", 2)
      <<~ROW
        <tr class="odd">
          <td class="bb1" align="center">#{idx + 1}</td>
          <td class="bb1"><a href="showTeilnehmer.php?p=20-7-*-2025/2026-*--859-#{cc_id}&amp;" title="#{last_name}, #{first_name} (#{cc_id})" class="cc_bluelink">#{last_name}</a></td>
          <td class="bb1">#{first_name}</td>
        </tr>
      ROW
    end.join
    "<html><body><table><tbody>#{rows}</tbody></table></body></html>"
  end

  # HTML fuer showMeldeliste.php (Meldeliste) — bb1 single-quote-Format (HAR-Goldvorlage 2026-06-10).
  #   <td class='bb1'><b>Nachname</b></td><td class='bb1'><b>Vorname</b></td><td class='bb1' align='center'>Pass-Nr</td>
  def build_meldeliste_html(players:)
    rows = players.map do |cc_id, label|
      last_first = label.split(" (").first.to_s
      last_name, first_name = last_first.split(", ", 2)
      first_name = first_name.presence || "Vorname"  # CC hat immer einen Vornamen; Test-Label ggf. ohne
      "<tr class='even'><td class='bb1' align='center'>1</td>" \
        "<td class='bb1'><b>#{last_name}</b></td><td class='bb1'><b>#{first_name}</b></td>" \
        "<td class='bb1' align='center'>#{cc_id}</td></tr>"
    end.join
    "<html><body><table>#{rows}</table></body></html>"
  end

  # AC-1: available_in_meldeliste kommt aus Tab-2-Differenz (Registrierte minus Akkreditierte)
  test "AC-1: available_in_meldeliste ist Tab-2 minus Tab-3 (Set-Differenz)" do
    build_mock(
      teilnehmer: [[42, "Hassendorf, Maja (42)"]],
      meldung: [[43, "Lange, Hendrik (43)"], [44, "Wendt, Sebastian (44)"]]
    )
    response = McpServer::Tools::LookupTeilnehmerliste.call(
      tournament_cc_id: 859, fed_cc_id: 20, branch_cc_id: 7, season: "2025/2026"
    )
    refute response.error?, "expected non-error; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])
    assert_equal "partial", body["phase"]
    assert_equal 1, body["counts"]["teilnehmer"]
    assert_equal 2, body["counts"]["meldung_open"]
    assert_equal [42], body["current_teilnehmer"].map { |p| p["cc_id"] }
    assert_equal [43, 44], body["available_in_meldeliste"].map { |p| p["cc_id"] }
    assert_match(/showMeldeliste\.php -2/, body["read_pfade"]["meldung"])
  end

  # AC-2: cc_lookup_teilnehmerliste macht keine POST-Calls (kein Edit-Buffer-Seiteneffekt)
  test "AC-2: kein POST-Call im Lookup (pure GET-Reads)" do
    mock = build_mock(
      teilnehmer: [[42, "A (42)"]],
      meldung: [[43, "B (43)"]]
    )
    McpServer::Tools::LookupTeilnehmerliste.call(
      tournament_cc_id: 859, fed_cc_id: 20, branch_cc_id: 7, season: "2025/2026"
    )
    post_calls = mock.calls.select { |c| c[0] == :post }
    assert_empty post_calls, "cc_lookup_teilnehmerliste darf keine POST-Calls machen; got: #{post_calls.inspect}"
  end

  test "Smoke-Befund DFP SU: 3 Teilnehmer + 0 Meldung -> phase=finalized" do
    build_mock(
      teilnehmer: [[42, "Hassendorf, Maja (42)"], [43, "Lange, Hendrik (43)"], [44, "Wendt, Sebastian (44)"]],
      meldung: []
    )
    response = McpServer::Tools::LookupTeilnehmerliste.call(
      tournament_cc_id: 859, fed_cc_id: 20, branch_cc_id: 7, season: "2025/2026"
    )
    refute response.error?, "expected non-error; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])
    assert_equal "finalized", body["phase"]
    assert_equal 3, body["counts"]["teilnehmer"]
    assert_equal 0, body["counts"]["meldung_open"]
    assert_equal 3, body["current_teilnehmer"].size
    assert_equal 42, body["current_teilnehmer"].first["cc_id"]
    assert_equal "Hassendorf, Maja", body["current_teilnehmer"].first["label"]
    # tournament_name kommt aus TournamentCc.find_by (Stammdaten-DB); nil ohne DB-Mock ist OK
    assert_nil body["tournament_name"]
  end

  test "phase=open: Meldeliste voll, Teilnehmerliste leer" do
    build_mock(
      teilnehmer: [],
      meldung: [[11683, "Nachtmann, Georg (11683)"], [10024, "Schroeder, Hans-Joerg (10024)"]]
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
      meldung: [[43, "B (43)"], [44, "C (44)"]]
    )
    response = McpServer::Tools::LookupTeilnehmerliste.call(
      tournament_cc_id: 891, fed_cc_id: 20, branch_cc_id: 7, season: "2025/2026"
    )
    body = JSON.parse(response.content.first[:text])
    assert_equal "partial", body["phase"]
  end

  test "phase=empty: beide leer" do
    build_mock(teilnehmer: [], meldung: [])
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

  # DEFER-25-9 Regression-Schutz: branch_cc_id-Default muss branch_cc.cc_id (admin-cc-id) liefern.
  test "DEFER-25-9: branchId Default nutzt branch_cc.cc_id (admin-cc-id), nicht Rails-FK" do
    region_cc_stub = Struct.new(:cc_id).new(20)
    branch_cc_stub = Struct.new(:cc_id, :region_cc).new(7, region_cc_stub)
    tournament_cc_stub = Struct.new(:branch_cc, :branch_cc_id, :season, :name).new(branch_cc_stub, 3, "2025/2026", nil)

    captured_p_params = []
    show_body = "<html><body><table></table></body></html>"
    ok = Struct.new(:code, :message, :body)
    mock = McpServer::Tools::MockClient.new
    mock.define_singleton_method(:get) do |action, params, opts|
      @calls << [:get, action, params, opts]
      captured_p_params << params[:p] if action == "showTeilnehmerliste"
      [ok.new("200", "OK", show_body), Nokogiri::HTML(show_body)]
    end
    mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      [ok.new("200", "OK", "<html></html>"), Nokogiri::HTML("<html></html>")]
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

    assert_not_empty captured_p_params, "GET showTeilnehmerliste sollte aufgerufen worden sein"
    captured_p_params.each do |p|
      assert_match(/\A20-7-/, p, "branchId muss branch_cc.cc_id=7 sein, nicht Rails-FK=3; got: #{p}")
    end
  end

  # Plan 25-01 T3b-QuoteFix Regression-Schutz (2026-06-02): CC sendet single quotes.
  # Mock liefert dasselbe HTML fuer Tab-2 und Tab-3 → phase=finalized (alle 3 registriert + akkreditiert).
  test "T3b-QuoteFix: parser akzeptiert single-quoted HTML (Live-CC-Format)" do
    body = <<~HTML
      <html><body><table><tbody>
      <tr><td><a href='showTeilnehmer.php?p=20-7-*-2025/2026-*--859-10165&amp;' title='Ben Ghaffar, Ramzi (10165)' class='cc_bluelink'>Ben Ghaffar</a></td></tr>
      <tr><td><a href='showTeilnehmer.php?p=20-7-*-2025/2026-*--859-10761&amp;' title='Einsiedler, Janni (10761)' class='cc_bluelink'>Einsiedler</a></td></tr>
      <tr><td><a href='showTeilnehmer.php?p=20-7-*-2025/2026-*--859-11353&amp;' title='Hepp, Neele (11353)' class='cc_bluelink'>Hepp</a></td></tr>
      </tbody></table></body></html>
    HTML
    ok = Struct.new(:code, :message, :body)
    mock = McpServer::Tools::MockClient.new
    mock.define_singleton_method(:get) { |_a, _p, _o| [ok.new("200", "OK", body), Nokogiri::HTML(body)] }
    mock.define_singleton_method(:post) { |_a, _p, _o| [ok.new("200", "OK", "<html></html>"), Nokogiri::HTML("<html></html>")] }
    McpServer::CcSession._client_override = mock

    response = McpServer::Tools::LookupTeilnehmerliste.call(
      tournament_cc_id: 859, fed_cc_id: 20, branch_cc_id: 7, season: "2025/2026"
    )
    refute response.error?, "expected non-error; got: #{response.content.first[:text]}"
    body_json = JSON.parse(response.content.first[:text])
    # Tab-2 und Tab-3 gleich → alle 3 registriert UND akkreditiert → phase=finalized, available=0
    assert_equal "finalized", body_json["phase"], "single-quote Regex muss matchen"
    assert_equal 3, body_json["counts"]["teilnehmer"]
    assert_equal 0, body_json["counts"]["meldung_open"]
    assert_equal [10165, 10761, 11353], body_json["current_teilnehmer"].map { |t| t["cc_id"] }
    assert_equal "Ben Ghaffar, Ramzi", body_json["current_teilnehmer"].first["label"]
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
