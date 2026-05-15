# frozen_string_literal: true

require "test_helper"

class McpServer::Tools::ListPlayersByNameTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    ENV["CC_FED_ID"] = nil
    ENV["CC_REGION"] = nil
    McpServer::CcSession.reset!
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    ENV["CC_FED_ID"] = nil
    ENV["CC_REGION"] = nil
  end

  test "validation: missing name returns error" do
    response = McpServer::Tools::ListPlayersByName.call(server_context: {cc_region: "NBV"})
    assert response.error?
    assert_match(/name/i, response.content.first[:text])
  end

  test "validation: name too short returns error" do
    response = McpServer::Tools::ListPlayersByName.call(name: "u", server_context: {cc_region: "NBV"})
    assert response.error?
    assert_match(/at least 2/i, response.content.first[:text])
  end

  test "validation: empty name returns error (blank treated as missing)" do
    response = McpServer::Tools::ListPlayersByName.call(name: "", server_context: {cc_region: "NBV"})
    assert response.error?
    assert_match(/name/i, response.content.first[:text])
  end

  # Plan 14-02.2 / B-3: shortname-Override-Logik entfernt. Tool ignoriert den Parameter
  # und nutzt strict server_context[:cc_region]. Statt "Region not found" für unknown
  # shortname läuft die Suche jetzt gegen die User-Region (NBV) — kein Error mehr.
  test "B-3: shortname-Override wird ignoriert, User-Region greift strict" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV region fixture missing" unless nbv
    response = McpServer::Tools::ListPlayersByName.call(name: "ullrich", shortname: "ZZZ-XYZ", server_context: {cc_region: "NBV"})
    refute response.error?, "shortname-Override darf nicht zu Error führen — strict server_context greift"
    body = JSON.parse(response.content.first[:text])
    assert_equal "NBV", body.dig("meta", "region")
  end

  test "D-14-G.7 / AC-1: Scenario-Config ohne Carambus.config.context → Scenario-Config-Diagnostic-Error" do
    response = McpServer::Tools::ListPlayersByName.call(name: "ullrich", server_context: {})
    assert response.error?
    assert_match(/Scenario-Config-Fehler.*Carambus\.config\.context/i, response.content.first[:text])
  end

  test "validation: unknown club_cc_id returns error when region resolvable" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV region fixture missing" unless nbv

    response = McpServer::Tools::ListPlayersByName.call(
      name: "ullrich",
      club_cc_id: 99_999_999,
      shortname: "NBV",
      server_context: {cc_region: "NBV"}
    )
    assert response.error?
    assert_match(/Club not found/i, response.content.first[:text])
  end

  test "happy path: matches by lastname fragment, region-scoped" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV region fixture missing" unless nbv

    sample = Player.joins(:player_rankings)
      .where(player_rankings: {region_id: nbv.id})
      .where.not(lastname: [nil, ""])
      .first
    skip "No NBV-ranked player in fixtures" unless sample

    fragment = sample.lastname.to_s[0, 4]
    skip "Sample lastname too short for substring search" if fragment.length < 2

    response = McpServer::Tools::ListPlayersByName.call(name: fragment, shortname: "NBV", server_context: {cc_region: "NBV"})
    refute response.error?, "Expected non-error; got: #{response.content.first[:text]}"

    body = JSON.parse(response.content.first[:text])
    assert_equal "NBV", body.dig("meta", "region")
    assert_equal "name", body.dig("meta", "filter_basis")
    assert_kind_of Integer, body.dig("meta", "match_count")
    assert_kind_of Array, body["players"]
    assert body["players"].length >= 1, "Expected ≥1 match for fragment '#{fragment}'"
    body["players"].each do |p|
      assert p.key?("id")
      assert p.key?("fl_name")
      assert p.key?("firstname")
      assert p.key?("lastname")
    end
  end

  test "happy path: matches by firstname fragment" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV region fixture missing" unless nbv

    sample = Player.joins(:player_rankings)
      .where(player_rankings: {region_id: nbv.id})
      .where.not(firstname: [nil, ""])
      .first
    skip "No NBV-ranked player with firstname" unless sample

    fragment = sample.firstname.to_s[0, 3]
    skip "Sample firstname too short" if fragment.length < 2

    response = McpServer::Tools::ListPlayersByName.call(name: fragment, shortname: "NBV", server_context: {cc_region: "NBV"})
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert body["players"].length >= 1
  end

  test "club_cc_id narrows result set" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV region fixture missing" unless nbv

    candidate = Player.joins(:player_rankings, :season_participations)
      .where(player_rankings: {region_id: nbv.id})
      .where.not(season_participations: {club_id: nil})
      .where.not(lastname: [nil, ""])
      .first
    skip "No NBV-ranked player with SeasonParticipation" unless candidate

    club = candidate.season_participations.where.not(club_id: nil).first&.club
    skip "Candidate has no resolvable club" unless club&.cc_id

    fragment = candidate.lastname.to_s[0, 3]
    skip "Sample lastname too short" if fragment.length < 2

    response = McpServer::Tools::ListPlayersByName.call(
      name: fragment,
      club_cc_id: club.cc_id,
      shortname: "NBV",
      server_context: {cc_region: "NBV"}
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_equal "name+club_cc_id", body.dig("meta", "filter_basis")
    assert_equal club.cc_id, body.dig("meta", "club_cc_id")
  end

  test "no-match returns empty players + match_count: 0" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV region fixture missing" unless nbv

    response = McpServer::Tools::ListPlayersByName.call(
      name: "ZZZ_NEVER_EXISTS_#{SecureRandom.hex(4)}",
      shortname: "NBV",
      server_context: {cc_region: "NBV"}
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_equal 0, body.dig("meta", "match_count")
    assert_equal 0, body.dig("meta", "returned")
    assert_equal [], body["players"]
  end

  test "sanitize_sql_like: percent in name treated as literal" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV region fixture missing" unless nbv

    # Sollte nicht crashen und 0 Treffer liefern (Percent als Literal wird kaum in echten Namen sein)
    response = McpServer::Tools::ListPlayersByName.call(
      name: "100%test",
      shortname: "NBV",
      server_context: {cc_region: "NBV"}
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_kind_of Integer, body.dig("meta", "match_count")
  end

  # Plan 14-02.2 / Befund E-1: Token-Search behebt Title-Präfix-Bug.
  test "E-1: Token-Search findet 'Dr. Gernot Ullrich' via Query 'Gernot Ullrich'" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV region fixture missing" unless nbv
    # Player „Dr. Gernot" wenn in fixtures vorhanden — sonst syntheticen via Player.where
    sample = Player.joins(:player_rankings)
      .where(player_rankings: {region_id: nbv.id})
      .where("firstname ILIKE ?", "Dr.%")
      .first
    skip "Kein 'Dr.'-prefixed Player in NBV-Fixtures" unless sample
    # Suche mit Plain-Name (ohne Dr.) — sollte trotzdem matchen
    fragment = "#{sample.firstname.to_s.sub(/^Dr\.\s*/i, "")} #{sample.lastname}"
    skip "Sample player name too short for token search" if fragment.length < 5

    response = McpServer::Tools::ListPlayersByName.call(name: fragment, server_context: {cc_region: "NBV"})
    refute response.error?, "Token-Search muss Title-Präfix-tolerant matchen — got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])
    cc_ids = body["players"].map { |p| p["cc_id"] }
    assert_includes cc_ids, sample.cc_id, "Token-Search muss '#{fragment}' gegen '#{sample.firstname} #{sample.lastname}' matchen"
  end

  test "E-1: Token-Search ist Order-independent ('Ullrich Gernot' = 'Gernot Ullrich')" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV region fixture missing" unless nbv
    sample = Player.joins(:player_rankings)
      .where(player_rankings: {region_id: nbv.id})
      .where.not(firstname: [nil, ""])
      .where.not(lastname: [nil, ""])
      .first
    skip "No usable NBV-ranked player" unless sample

    # Forward order
    forward = "#{sample.firstname.to_s.split.last} #{sample.lastname}"
    # Reverse order
    reverse = "#{sample.lastname} #{sample.firstname.to_s.split.last}"

    forward_resp = McpServer::Tools::ListPlayersByName.call(name: forward, server_context: {cc_region: "NBV"})
    reverse_resp = McpServer::Tools::ListPlayersByName.call(name: reverse, server_context: {cc_region: "NBV"})

    refute forward_resp.error?
    refute reverse_resp.error?
    forward_body = JSON.parse(forward_resp.content.first[:text])
    reverse_body = JSON.parse(reverse_resp.content.first[:text])
    forward_ids = forward_body["players"].map { |p| p["cc_id"] }
    reverse_ids = reverse_body["players"].map { |p| p["cc_id"] }
    assert_includes forward_ids, sample.cc_id, "Forward order must match"
    assert_includes reverse_ids, sample.cc_id, "Reverse order must match (Order-independent)"
  end

  test "E-2: Output-Struktur hat cc_id als Primary + dbu_nr als informativ" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV region fixture missing" unless nbv
    sample = Player.joins(:player_rankings)
      .where(player_rankings: {region_id: nbv.id})
      .where.not(lastname: [nil, ""])
      .first
    skip "No NBV-ranked player" unless sample
    fragment = sample.lastname.to_s[0, 4]
    skip "Sample too short" if fragment.length < 2

    response = McpServer::Tools::ListPlayersByName.call(name: fragment, server_context: {cc_region: "NBV"})
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert body["players"].length >= 1
    first = body["players"].first
    # cc_id muss vorhanden sein, dbu_nr-Key muss existieren (auch wenn Wert nil ist)
    assert first.key?("cc_id"), "cc_id muss in Output-Struktur sein"
    assert first.key?("dbu_nr"), "dbu_nr-Key (informativ) muss in Output sein"
  end

  test "result respects MAX_RESULTS limit" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV region fixture missing" unless nbv

    # Sehr breites Match-Fragment ('e' findet sehr viele Spieler)
    response = McpServer::Tools::ListPlayersByName.call(name: "er", shortname: "NBV", server_context: {cc_region: "NBV"})
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert body.dig("meta", "returned").to_i <= McpServer::Tools::ListPlayersByName::MAX_RESULTS
    assert_equal 50, body.dig("meta", "limit")
  end
end
