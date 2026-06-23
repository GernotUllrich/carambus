# frozen_string_literal: true

require "test_helper"

# Plan 45-02: cc_party_lineup — Aufstellung/Einzelpartien einer Party (party_games).
class McpServer::Tools::PartyLineupTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    McpServer::CcSession.reset!
    @nbv = regions(:nbv)
    @season = seasons(:current)
    @pool = Branch.create!(name: "Pool")
    @league = League.create!(name: "P4502L Pool Liga", shortname: "P4502L-PL",
      organizer: @nbv, season: @season, discipline: @pool, cc_id: 945_230)
    @a = LeagueTeam.create!(league: @league, name: "P4502L Team A")
    @b = LeagueTeam.create!(league: @league, name: "P4502L Team B")
    @party = Party.create!(league: @league, league_team_a: @a, league_team_b: @b,
      host_league_team: @a, day_seqno: 1, date: Date.new(2026, 1, 20), data: {"result" => "1:0"})
    @pg = PartyGame.create!(party: @party, seqno: 1, discipline: @pool,
      data: {"result" => {"Ergebnis" => "7:0"}})
    # 2. Party ohne party_games (Leer-Pfad)
    @empty_party = Party.create!(league: @league, league_team_a: @b, league_team_b: @a,
      host_league_team: @b, day_seqno: 2, date: Date.new(2026, 2, 20), data: {})
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    [@pg, @party, @empty_party, @a, @b, @league, @pool].compact.each { |r| r.destroy if r&.persisted? }
  end

  def body_of(resp)
    JSON.parse(resp.content.first[:text])
  end

  test "AC-3: party_id-Pfad listet Einzelpartien + gegatete Quelle + public_url" do
    skip "fixtures missing" unless @nbv && users(:system_admin)
    resp = McpServer::Tools::PartyLineup.call(
      party_id: @party.id, server_context: {cc_region: "NBV", user_id: users(:system_admin).id}
    )
    refute resp.error?, "got: #{resp.content.first[:text]}"
    body = body_of(resp)
    assert_equal 1, body["meta"]["game_count"]
    g = body["games"].first
    assert_equal 1, g["seqno"]
    assert_equal "Pool", g["discipline"]
    assert_equal({"Ergebnis" => "7:0"}, g["result"])
    assert_equal "P4502L Team A", body["party"]["team_a"]
    assert_equal McpServer::Tools::BaseTool::SOURCE_NOTES[:db_mirror], body["meta"]["source"]
    # public_url: falls baubar ein echter sb_spielplan-Link, nie Müll (Fixture ohne public_cc_url_base → ggf. abwesend).
    pub = body["meta"]["public_url"]
    if pub
      assert_match(%r{sb_spielplan\.php\?p=}, pub)
      refute_match(/billard\.de/, pub)
    end
  end

  test "AC-3: league_id + day_seqno-Pfad findet dieselbe Party" do
    skip "fixtures missing" unless @nbv
    resp = McpServer::Tools::PartyLineup.call(
      league_id: @league.id, day_seqno: 1, server_context: {cc_region: "NBV"}
    )
    refute resp.error?, "got: #{resp.content.first[:text]}"
    assert_equal @party.id, body_of(resp)["party"]["id"]
  end

  test "AC-3: Party ohne party_games → leere Aufstellung, kein Crash" do
    skip "fixtures missing" unless @nbv
    resp = McpServer::Tools::PartyLineup.call(party_id: @empty_party.id, server_context: {cc_region: "NBV"})
    refute resp.error?
    body = body_of(resp)
    assert_equal 0, body["meta"]["game_count"]
    assert_equal [], body["games"]
  end

  test "AC-4: Party einer Liga außerhalb der Region → Fehler (kein Cross-Region-Leak)" do
    skip "fixtures missing" unless @nbv && regions(:bbv)
    ol = League.create!(name: "P4502L BBV", shortname: "P4502L-BBV",
      organizer: regions(:bbv), season: @season, discipline: @pool, cc_id: 945_231)
    ot_a = LeagueTeam.create!(league: ol, name: "P4502L BBV A")
    ot_b = LeagueTeam.create!(league: ol, name: "P4502L BBV B")
    op = Party.create!(league: ol, league_team_a: ot_a, league_team_b: ot_b,
      host_league_team: ot_a, day_seqno: 1, date: Date.new(2026, 1, 20), data: {})
    resp = McpServer::Tools::PartyLineup.call(party_id: op.id, server_context: {cc_region: "NBV"})
    assert resp.error?
    assert_match(/gehört nicht zur Region|nicht gefunden/i, resp.content.first[:text])
  ensure
    op&.destroy
    [ot_a, ot_b].compact.each(&:destroy)
    ol&.destroy
  end

  test "Registrierung in BASE_READ_TOOLS + ToolRegistry" do
    assert_includes McpServer::RoleToolMap::BASE_READ_TOOLS, :PartyLineup
    assert_equal "cc_party_lineup", McpServer::Tools::PartyLineup.tool_name
    assert_includes McpServer::ToolRegistry.tool_classes_for(users(:valid)), McpServer::Tools::PartyLineup
  end
end
