# frozen_string_literal: true
require "test_helper"

# Tests for cc_lookup_tournament — DB-first lookup + Phase-5 Detail-Output
# (location_text, tournament_start/end, accredation_end) und optionale
# Live-Meldeliste-Read via showCommittedMeldeliste.
#
# Mock-Mode-only: setup setzt CARAMBUS_MCP_MOCK=1 und _client_override.
class McpServer::Tools::LookupTournamentTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    ENV["CC_FED_ID"] = nil
    ENV["CC_REGION"] = nil
    McpServer::CcSession.reset!
    McpServer::CcSession.session_id = "TEST_SESSION_ID"
    McpServer::CcSession.session_started_at = Time.now
    @mock = McpServer::Tools::MockClient.new
    McpServer::CcSession._client_override = @mock
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    ENV["CC_FED_ID"] = nil
    ENV["CC_REGION"] = nil
    McpServer::CcSession._client_override = nil
    McpServer::CcSession.reset!
  end

  test "validation: missing meisterschaft_id und tournament_id liefert error" do
    response = McpServer::Tools::LookupTournament.call(server_context: nil)
    assert response.error?
    assert_match(/Missing required parameter/i, response.content.first[:text])
  end

  test "DB-first miss: TournamentCc nicht gefunden liefert error" do
    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: 99_999_999,
      server_context: nil
    )
    assert response.error?
    assert_match(/not found/i, response.content.first[:text])
  end

  test "Phase-5 Detail-Output: liefert location_text/tournament_start/end zusätzlich zu Core-Feldern" do
    sample = TournamentCc.where.not(cc_id: nil).first
    skip "No TournamentCc fixtures available" unless sample

    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: sample.cc_id,
      server_context: nil
    )
    refute response.error?, "Expected non-error; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])

    # Bestehende Core-Felder bleiben:
    assert_equal sample.id, body["id"]
    assert_equal sample.cc_id, body["cc_id"]
    assert_equal sample.name, body["name"]
    assert_equal sample.season, body["season"]

    # Phase-5 Detail-Felder existieren als Keys (Werte können nil sein, je nach Sample):
    assert body.key?("location_text"), "location_text muss im Output sein"
    assert body.key?("tournament_start"), "tournament_start muss im Output sein"
    assert body.key?("tournament_end"), "tournament_end muss im Output sein"
    assert body.key?("accredation_end"), "accredation_end muss im Output sein"

    # Werte korrekt aus DB gelesen:
    assert_equal sample.location_text, body["location_text"]
    assert_equal sample.tournament_start&.iso8601, body["tournament_start"]
    assert_equal sample.tournament_end&.iso8601, body["tournament_end"]
  end

  test "Backwards-Compat: ohne with_committed_list KEIN committed_players Feld im Output" do
    sample = TournamentCc.where.not(cc_id: nil).first
    skip "No TournamentCc fixtures available" unless sample

    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: sample.cc_id,
      server_context: nil
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])

    refute body.key?("committed_players"), "committed_players darf NICHT im Output sein wenn with_committed_list nicht gesetzt"
    refute body.key?("meta"), "meta-Feld nur bei Warnungen — sollte ohne with_committed_list nicht erscheinen"
    assert @mock.calls.empty?, "Ohne with_committed_list darf KEIN CC-Call passieren — got #{@mock.calls.inspect}"
  end

  test "with_committed_list: ohne registration_list_cc-Beziehung → committed_players:nil + meta-Warnung" do
    sample = TournamentCc.where.not(cc_id: nil).where(registration_list_cc_id: nil).first
    skip "No TournamentCc without registration_list_cc available" unless sample

    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: sample.cc_id,
      with_committed_list: true,
      server_context: nil
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])

    assert_nil body["committed_players"]
    assert body["meta"], "meta soll Warnung enthalten"
    assert_match(/registration_list_cc/i, body["meta"]["committed_list_warning"])
    # Defensive: kein CC-Call gemacht (nichts aufzulösen)
    assert @mock.calls.empty?
  end

  test "with_committed_list: meldeliste_cc_id-Override → CC-Call mit 8-Felder-Payload + Player-cc_ids geparst" do
    sample = TournamentCc.where.not(cc_id: nil).first
    skip "No TournamentCc fixtures available" unless sample

    # Mock-Response: 2 Player-cc_id-Marker im HTML-Body
    body_html = %(<html><body><table>
      <tr><td align="center">10031</td><td>Mustermann</td></tr>
      <tr><td align="center">10413</td><td>Auel</td></tr>
    </table></body></html>)
    @mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      if action == "showCommittedMeldeliste"
        [Struct.new(:code, :message, :body).new("200", "OK", body_html), Nokogiri::HTML(body_html)]
      else
        [Struct.new(:code, :message, :body).new("200", "OK", ""), Nokogiri::HTML("<html></html>")]
      end
    end

    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: sample.cc_id,
      with_committed_list: true,
      meldeliste_cc_id: 1310,
      fed_id: 20,
      server_context: nil
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])

    # Geparste Player-cc_ids:
    assert_equal [{ "cc_id" => 10031 }, { "cc_id" => 10413 }], body["committed_players"]

    # CC-Call wurde gemacht mit 8-Felder-Payload:
    call = @mock.calls.find { |verb, action, _, _| verb == :post && action == "showCommittedMeldeliste" }
    assert call
    _, _, params, _ = call
    expected_keys = %i[clubId fedId branchId disciplinId catId season meldelisteId sortOrder].sort
    assert_equal expected_keys, params.keys.sort,
      "Verify-Payload muss genau 8 Felder haben (analog Phase-5-D3-Bugfix); got #{params.keys.sort.inspect}"
    assert_equal 1310, params[:meldelisteId], "meldelisteId aus Override-Param"
    assert_equal 20, params[:fedId]
    assert_equal "player", params[:sortOrder]
  end

  test "with_committed_list: HTTP-Fehler → committed_players:nil + meta-Warnung (defensiv, keine Exception)" do
    sample = TournamentCc.where.not(cc_id: nil).first
    skip "No TournamentCc fixtures available" unless sample

    @mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      [Struct.new(:code, :message, :body).new("500", "Internal Server Error", ""), Nokogiri::HTML("<html></html>")]
    end

    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: sample.cc_id,
      with_committed_list: true,
      meldeliste_cc_id: 1310,
      fed_id: 20,
      server_context: nil
    )
    refute response.error?, "Tool darf bei HTTP 500 keine Exception werfen, sondern defensiv reagieren"
    body = JSON.parse(response.content.first[:text])

    assert_nil body["committed_players"]
    assert_match(/HTTP 500/, body["meta"]["committed_list_warning"])
  end

  test "with_committed_list: Exception in client.post → committed_players:nil + meta-Warnung (rescue)" do
    sample = TournamentCc.where.not(cc_id: nil).first
    skip "No TournamentCc fixtures available" unless sample

    @mock.define_singleton_method(:post) do |*_|
      raise RuntimeError, "simulated network failure"
    end

    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: sample.cc_id,
      with_committed_list: true,
      meldeliste_cc_id: 1310,
      fed_id: 20,
      server_context: nil
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])

    assert_nil body["committed_players"]
    assert_match(/RuntimeError|Exception/i, body["meta"]["committed_list_warning"])
  end
end
