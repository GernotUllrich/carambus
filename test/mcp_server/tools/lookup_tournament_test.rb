# frozen_string_literal: true

require "test_helper"

# Tests for cc_lookup_tournament — DB-first lookup + Phase-5 Detail-Output
# (location_text, tournament_start/end, accredation_end) + Live-Meldeliste-Read.
#
# Plan 14-02.3 updates:
# - F-4: cc_id-Alias-Tests
# - F-7: Season-Default-Filter-Tests
# - D-14-02-G strict User-Context (server_context: {cc_region: "NBV"})
# - F-6 Sportwart-Vokabular in Error-Messages
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

  test "validation: missing meisterschaft_id / cc_id / tournament_id / name liefert error" do
    response = McpServer::Tools::LookupTournament.call(server_context: nil)
    assert response.error?
    msg = response.content.first[:text]
    assert_match(/meisterschaft_id|cc_id|tournament_id|name/i, msg)
  end

  test "DB-first miss: TournamentCc nicht gefunden liefert error mit Sportwart-Vokabular" do
    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: 99_999_999,
      server_context: {cc_region: "NBV"}
    )
    assert response.error?
    assert_match(/nicht in deiner Region/i, response.content.first[:text])
  end

  test "Plan 14-02.1-fix: ohne server_context cc_region → Profile-Edit-Hinweis-Error" do
    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: 890,
      server_context: nil
    )
    assert response.error?
    assert_match(/Scenario-Config-Fehler.*Carambus\.config\.context/i, response.content.first[:text])
  end

  # Plan 14-02.3 / F-4: cc_id ist Alias für meisterschaft_id.
  test "F-4 cc_id-Alias: cc_id wird wie meisterschaft_id behandelt" do
    sample = TournamentCc.where.not(cc_id: nil).where.not(context: nil).first
    skip "No TournamentCc fixtures available" unless sample

    response = McpServer::Tools::LookupTournament.call(
      cc_id: sample.cc_id,
      server_context: {cc_region: sample.context.to_s.upcase}
    )
    refute response.error?, "cc_id-Alias muss funktionieren; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])
    assert_equal sample.cc_id, body["cc_id"]
  end

  test "F-4 cc_id-Alias: meisterschaft_id hat Präzedenz wenn beide gesetzt" do
    sample = TournamentCc.where.not(cc_id: nil).where.not(context: nil).first
    skip "No TournamentCc fixtures available" unless sample

    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: sample.cc_id,
      cc_id: 99_999_999,  # falscher cc_id-Wert; meisterschaft_id soll gewinnen
      server_context: {cc_region: sample.context.to_s.upcase}
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_equal sample.cc_id, body["cc_id"]
  end

  test "Phase-5 Detail-Output: liefert location_text/tournament_start/end zusätzlich zu Core-Feldern" do
    sample = TournamentCc.where.not(cc_id: nil).where.not(context: nil).first
    skip "No TournamentCc fixtures available" unless sample

    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: sample.cc_id,
      server_context: {cc_region: sample.context.to_s.upcase}
    )
    refute response.error?, "Expected non-error; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])

    # Bestehende Core-Felder bleiben:
    assert_equal sample.id, body["id"]
    assert_equal sample.cc_id, body["cc_id"]
    assert_equal sample.name, body["name"]

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
    sample = TournamentCc.where.not(cc_id: nil).where.not(context: nil).first
    skip "No TournamentCc fixtures available" unless sample

    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: sample.cc_id,
      server_context: {cc_region: sample.context.to_s.upcase}
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])

    refute body.key?("committed_players"), "committed_players darf NICHT im Output sein wenn with_committed_list nicht gesetzt"
    refute body.key?("meta"), "meta-Feld nur bei Warnungen — sollte ohne with_committed_list nicht erscheinen"
    assert @mock.calls.empty?, "Ohne with_committed_list darf KEIN CC-Call passieren — got #{@mock.calls.inspect}"
  end

  test "with_committed_list: ohne registration_list_cc-Beziehung → committed_players:nil + meta-Warnung" do
    sample = TournamentCc.where.not(cc_id: nil).where.not(context: nil).where(registration_list_cc_id: nil).first
    skip "No TournamentCc without registration_list_cc available" unless sample

    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: sample.cc_id,
      with_committed_list: true,
      server_context: {cc_region: sample.context.to_s.upcase}
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
    sample = TournamentCc.where.not(cc_id: nil).where.not(context: nil).first
    skip "No TournamentCc fixtures available" unless sample

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
      server_context: {cc_region: sample.context.to_s.upcase}
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])

    assert_equal [{"cc_id" => 10031}, {"cc_id" => 10413}], body["committed_players"]

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
    sample = TournamentCc.where.not(cc_id: nil).where.not(context: nil).first
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
      server_context: {cc_region: sample.context.to_s.upcase}
    )
    refute response.error?, "Tool darf bei HTTP 500 keine Exception werfen, sondern defensiv reagieren"
    body = JSON.parse(response.content.first[:text])

    assert_nil body["committed_players"]
    assert_match(/HTTP 500/, body["meta"]["committed_list_warning"])
  end

  test "with_committed_list: Exception in client.post → committed_players:nil + meta-Warnung (rescue)" do
    sample = TournamentCc.where.not(cc_id: nil).where.not(context: nil).first
    skip "No TournamentCc fixtures available" unless sample

    @mock.define_singleton_method(:post) do |*_|
      raise "simulated network failure"
    end

    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: sample.cc_id,
      with_committed_list: true,
      meldeliste_cc_id: 1310,
      fed_id: 20,
      server_context: {cc_region: sample.context.to_s.upcase}
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])

    assert_nil body["committed_players"]
    assert_match(/RuntimeError|Exception/i, body["meta"]["committed_list_warning"])
  end

  # Plan 14-02.3 / D-14-02-G: cc_id-Lookup respektiert server_context cc_region (strict).
  test "Region-Filter: cc_id-Lookup respektiert User-Region via server_context" do
    sample = TournamentCc.where.not(cc_id: nil).where.not(context: nil).first
    skip "No TournamentCc fixtures with context available" unless sample

    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: sample.cc_id,
      server_context: {cc_region: sample.context.to_s.upcase}
    )
    refute response.error?, "Expected non-error in matching region; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])
    assert_equal sample.cc_id, body["cc_id"]
    assert_equal sample.context, body["context"]
  end

  test "Region-Filter: cc_id-Lookup mit nicht-passender User-Region → Error" do
    sample = TournamentCc.where.not(cc_id: nil).where.not(context: nil).first
    skip "No TournamentCc fixtures with context available" unless sample
    other_region = (%w[NBV BVBW BBV LSBVH NSBV BSV] - [sample.context.to_s.upcase]).first

    response = McpServer::Tools::LookupTournament.call(
      meisterschaft_id: sample.cc_id,
      server_context: {cc_region: other_region}
    )
    assert response.error?, "Expected error when cc_id not in User-Region"
    msg = response.content.first[:text]
    assert_match(/nicht in deiner Region/i, msg)
  end

  test "tournament_id-Lookup: KEIN Region-Filter (Carambus-intern ist region-eindeutig)" do
    sample = TournamentCc.where.not(tournament_id: nil).where.not(context: nil).first
    skip "No TournamentCc fixtures with tournament_id available" unless sample

    response = McpServer::Tools::LookupTournament.call(
      tournament_id: sample.tournament_id,
      server_context: {cc_region: "NBV"}  # auch wenn User in NBV ist, tournament_id ist global
    )
    refute response.error?, "tournament_id-Lookup ist region-blind; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])
    assert_equal sample.tournament_id, body["tournament_id"]
  end

  # Plan 10-06 Task 1 (D-10-04-J Vokabular-Schicht): Name-Search mit Disambiguation.
  test "Name-Search: 0 Treffer → Tool-Error mit Workaround-Hinweisen" do
    needle = "ZzzNonexistent#{SecureRandom.hex(8)}"
    response = McpServer::Tools::LookupTournament.call(name: needle, server_context: {cc_region: "NBV"})
    assert response.error?
    msg = response.content.first[:text]
    assert_match(/Kein Turnier/i, msg)
    assert_match(/Versuche|kürzerer Suchbegriff|tournament_id|season/i, msg)
  end

  test "Name-Search: erfolgreich liefert candidates-Array" do
    sample = TournamentCc.where.not(name: [nil, ""]).where.not(context: nil).first
    skip "No TournamentCc fixtures with name+context available" unless sample
    needle = sample.name.to_s[0, [sample.name.length, 5].min]
    skip "Sample name too short" if needle.length < 3

    # Plan 14-02.3 / F-7 NULL-tolerant Season-Filter: sample mit context.upcase als User-Region.
    response = McpServer::Tools::LookupTournament.call(
      name: needle,
      server_context: {cc_region: sample.context.to_s.upcase}
    )
    refute response.error?, "Expected non-error; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])
    assert_operator body["candidates"].length, :>=, 1
    body["candidates"].each do |c|
      assert_match(/#{Regexp.escape(needle)}/i, c["name"].to_s)
    end
  end

  # Plan 14-02.3 / F-7: Season-Default-Filter (NULL-tolerant).
  test "F-7 Season-Default-Filter: Name-Search meta.season ist current_season" do
    sample = TournamentCc.where.not(name: [nil, ""]).where.not(context: nil).first
    skip "No TournamentCc fixtures available" unless sample
    skip "Season-Fixtures fehlen" if Season.current_season.nil?
    needle = sample.name.to_s[0, [sample.name.length, 3].min]
    skip "Sample name too short" if needle.length < 3

    response = McpServer::Tools::LookupTournament.call(
      name: needle,
      server_context: {cc_region: sample.context.to_s.upcase}
    )
    if response.error?
      # 0 Treffer ist ein zulässiges Ergebnis wenn Season-Filter alle ausschließt
      assert_match(/Saison|season/i, response.content.first[:text])
    else
      body = JSON.parse(response.content.first[:text])
      assert_equal Season.current_season.name, body["meta"]["season"]
    end
  end

  # Plan 14-02.3 / F-7: explicit season-override.
  test "F-7 Season-Override: explicit season-Parameter wechselt Filter" do
    skip "Season fixtures fehlen" if Season.count < 2
    other_season = Season.where.not(name: Season.current_season&.name).first
    skip "Keine andere Season verfügbar" if other_season.nil?

    response = McpServer::Tools::LookupTournament.call(
      name: "Zzz-nonexistent",
      season: other_season.name,
      server_context: {cc_region: "NBV"}
    )
    # 0 Treffer ist ok — wichtig ist dass season-Override propagiert.
    assert response.error?
    assert_match(/Saison '#{Regexp.escape(other_season.name)}'/, response.content.first[:text])
  end
end
