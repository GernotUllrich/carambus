# frozen_string_literal: true

require "test_helper"

# Plan 46-01: cc_set_party_lineup — lokale Aufstellungs-Vorbereitung einer Party
# (party-scoped Seedings role+position). armed-Dry-Run + Pre-Validation + idempotentes
# Ersetzen + Read-Back; rein lokal (kein CC-Touch). Muster wie cc_party_lineup-Setup.
class McpServer::Tools::SetPartyLineupTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    McpServer::CcSession.reset!
    @nbv = regions(:nbv)
    @season = seasons(:current)
    @pool = Branch.create!(name: "Pool")
    @league = League.create!(name: "P4601 Pool Liga", shortname: "P4601-PL",
      organizer: @nbv, season: @season, discipline: @pool, cc_id: 946_010)
    @a = LeagueTeam.create!(league: @league, name: "P4601 Team A")
    @b = LeagueTeam.create!(league: @league, name: "P4601 Team B")
    @party = Party.create!(league: @league, league_team_a: @a, league_team_b: @b,
      host_league_team: @a, day_seqno: 1, date: Date.new(2026, 3, 20), team_size: 4, data: {})

    # Kader Team A (3 Spieler via league_team-Seedings = Saison-Roster)
    @p1 = Player.create!(region: @nbv, lastname: "Alpha", firstname: "Anton")
    @p2 = Player.create!(region: @nbv, lastname: "Beta", firstname: "Bea")
    @p3 = Player.create!(region: @nbv, lastname: "Gamma", firstname: "Cliff")
    [@p1, @p2, @p3].each { |pl| Seeding.create!(player: pl, league_team: @a) }
    @outsider = Player.create!(region: @nbv, lastname: "Zeta", firstname: "Zoe") # NICHT im Kader

    # Sportwart (Pool) → authorized
    @sw = User.create!(email: "p4601_sw@test.de", password: "password123", persona_grants: ["sportwart"])
    @sw.sportwart_disciplines << @pool
    @ctx = {cc_region: "NBV", user_id: @sw.id}
  end

  teardown { ENV["CARAMBUS_MCP_MOCK"] = nil }

  def call(**kw)
    McpServer::Tools::SetPartyLineup.call(server_context: @ctx, **kw)
  end

  def body(res)
    JSON.parse(res.content.first[:text])
  end

  test "AC-1: armed setzt Aufstellung als party-scoped Seedings (role + position) + Read-Back" do
    res = call(party_id: @party.id, team: "a", armed: true,
      players: [{player_id: @p1.id, position: 1}, {player_id: @p2.id, position: 2}, {player_id: @p3.id, position: 3}])
    refute res.error?, "got: #{res.content.first[:text]}"
    b = body(res)
    assert_equal true, b["ok"]
    assert_equal 3, b["lineup"].length

    seedings = @party.seedings.where(role: "team_a").order(:position)
    assert_equal 3, seedings.count
    assert_equal [@p1.id, @p2.id, @p3.id], seedings.map(&:player_id)
    assert_equal [1, 2, 3], seedings.map(&:position)
    assert seedings.all? { |s| s.tournament_id == @party.id && s.tournament_type == "Party" }
    assert seedings.all? { |s| s.league_team_id.nil? }, "Lineup-Seedings sind tournament-scoped, nicht league_team"
  end

  test "AC-1: Spieler per Name aus dem Kader auflösbar" do
    res = call(party_id: @party.id, team: "a", armed: true,
      players: [{player_name: "Alpha"}, {player_name: "Beta"}])
    refute res.error?, "got: #{res.content.first[:text]}"
    assert_equal [@p1.id, @p2.id], @party.seedings.where(role: "team_a").order(:position).map(&:player_id)
  end

  test "AC-2: armed:false = Dry-Run-Echo, kein Write" do
    res = call(party_id: @party.id, team: "a", players: [{player_id: @p1.id}]) # armed default false
    refute res.error?
    b = body(res)
    assert_equal false, b["ok"]
    assert_equal "dry_run", b["reason"]
    assert_equal 1, b["planned"].length
    assert_equal 0, @party.seedings.where(role: "team_a").count, "Dry-Run darf nichts schreiben"
  end

  test "AC-3: Spieler nicht im Kader → Reject, kein Write" do
    res = call(party_id: @party.id, team: "a", armed: true, players: [{player_id: @outsider.id}])
    assert res.error?
    assert_match(/Kader/i, res.content.first[:text])
    assert_equal 0, @party.seedings.where(role: "team_a").count
  end

  test "AC-3: doppelte Position → Reject" do
    res = call(party_id: @party.id, team: "a", armed: true,
      players: [{player_id: @p1.id, position: 1}, {player_id: @p2.id, position: 1}])
    assert res.error?
    assert_match(/Position/i, res.content.first[:text])
    assert_equal 0, @party.seedings.where(role: "team_a").count
  end

  test "AC-3: doppelter Spieler → Reject" do
    res = call(party_id: @party.id, team: "a", armed: true,
      players: [{player_id: @p1.id, position: 1}, {player_id: @p1.id, position: 2}])
    assert res.error?
    assert_match(/nur einmal/i, res.content.first[:text])
  end

  test "AC-3: out-of-scope User (read-only) → nicht zuständig, kein Write" do
    res = McpServer::Tools::SetPartyLineup.call(
      server_context: {cc_region: "NBV", user_id: users(:player).id},
      party_id: @party.id, team: "a", armed: true, players: [{player_id: @p1.id}]
    )
    assert res.error?
    assert_match(/nicht zuständig/i, res.content.first[:text])
    assert_equal 0, @party.seedings.where(role: "team_a").count
  end

  test "AC-4: idempotentes Ersetzen — kein Duplikat, alte Aufstellung weg" do
    call(party_id: @party.id, team: "a", armed: true,
      players: [{player_id: @p1.id, position: 1}, {player_id: @p2.id, position: 2}, {player_id: @p3.id, position: 3}])
    assert_equal 3, @party.seedings.where(role: "team_a").count

    res = call(party_id: @party.id, team: "a", armed: true,
      players: [{player_id: @p3.id, position: 1}, {player_id: @p1.id, position: 2}])
    refute res.error?, "got: #{res.content.first[:text]}"
    seedings = @party.seedings.where(role: "team_a").order(:position)
    assert_equal 2, seedings.count, "alte Aufstellung ersetzt, nicht dupliziert"
    assert_equal [@p3.id, @p1.id], seedings.map(&:player_id)
  end

  test "AC-4: Cross-Region-Party → Fehler (kein Cross-Region-Leak)" do
    skip "fixture bbv fehlt" unless regions(:bbv)
    ol = League.create!(name: "P4601 BBV", shortname: "P4601-BBV",
      organizer: regions(:bbv), season: @season, discipline: @pool, cc_id: 946_099)
    ota = LeagueTeam.create!(league: ol, name: "P4601 BBV A")
    otb = LeagueTeam.create!(league: ol, name: "P4601 BBV B")
    op = Party.create!(league: ol, league_team_a: ota, league_team_b: otb,
      host_league_team: ota, day_seqno: 1, date: Date.new(2026, 3, 20), data: {})
    res = call(party_id: op.id, team: "a", armed: true, players: [{player_id: @p1.id}])
    assert res.error?
    assert_match(/gehört nicht zur Region|nicht gefunden/i, res.content.first[:text])
  end

  test "AC-5: Registrierung in WRITE_TOOLS + Tool-Name + write-gegated sichtbar" do
    assert_includes McpServer::RoleToolMap::WRITE_TOOLS, :SetPartyLineup
    assert_equal "cc_set_party_lineup", McpServer::Tools::SetPartyLineup.tool_name
    assert_equal false, McpServer::Tools::SetPartyLineup.annotations_value.read_only_hint
    # Write-Tools sind nur auf dem Local-Server sichtbar (Authority-Chat read-only, Phase 40).
    # Sportwart (cc_write_access?) sieht das Tool dort; reiner player nie.
    McpServer::ToolRegistry.stub(:local_server?, true) do
      assert_includes McpServer::ToolRegistry.tool_classes_for(@sw), McpServer::Tools::SetPartyLineup
      assert_not_includes McpServer::ToolRegistry.tool_classes_for(users(:player)), McpServer::Tools::SetPartyLineup
    end
  end

  test "league_id + day_seqno-Pfad findet dieselbe Party" do
    res = call(league_id: @league.id, day_seqno: 1, team: "a", players: [{player_id: @p1.id}])
    refute res.error?, "got: #{res.content.first[:text]}"
    assert_equal @party.id, body(res)["party"]["id"]
  end
end
