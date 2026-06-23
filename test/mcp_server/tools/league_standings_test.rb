# frozen_string_literal: true

require "test_helper"

# Plan 45-02: cc_league_standings — Tabellenstand einer Liga.
# AC-1 (Dispatch Pool/Snooker/Karambol + Kegel graceful), AC-4 (Region-Scope-Reject),
# AC-5 (echter public_url statt Halluzination), source-Gating (D-40-1).
class McpServer::Tools::LeagueStandingsTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    McpServer::CcSession.reset!

    @nbv = regions(:nbv)
    @season = seasons(:current)
    @pool = Branch.create!(name: "Pool")
    @league = League.create!(name: "P4502 Pool Liga", shortname: "P4502-PL",
      organizer: @nbv, season: @season, discipline: @pool, cc_id: 945_2001)
    @t1 = LeagueTeam.create!(league: @league, name: "P4502 Team A")
    @t2 = LeagueTeam.create!(league: @league, name: "P4502 Team B")
    @party = Party.create!(league: @league, league_team_a: @t1, league_team_b: @t2,
      day_seqno: 1, date: Time.zone.parse("2025-09-20 15:00"), data: {"result" => "3:1"})

    @kegel = Branch.create!(name: "Kegel")
    @kegel_league = League.create!(name: "P4502 Kegel Liga", shortname: "P4502-KL", organizer: @nbv,
      season: @season, discipline: @kegel, cc_id: 945_2009)

    # Liga außerhalb der Region (organizer_id zeigt nicht auf @nbv) → Region-Scope-Reject.
    @foreign = League.create!(name: "P4502 Foreign", shortname: "P4502-FN", organizer_type: "Region",
      organizer_id: @nbv.id + 10_000_000, season: @season, discipline: @pool, cc_id: 945_2099)
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    [@party, @t1, @t2, @league, @kegel_league, @foreign, @pool, @kegel].compact.each { |r| r.destroy if r&.persisted? }
  end

  def call(opts)
    McpServer::Tools::LeagueStandings.call(server_context: {cc_region: "NBV"}, **opts)
  end

  # AC-1: Pool-Liga → disziplin-korrekter Tabellenstand (Dispatch via branch.name).
  test "AC-1: Pool-Liga liefert Tabellenstand mit Platz/Punkten je Mannschaft" do
    skip "NBV fixtures missing" unless @nbv
    res = call(league_id: @league.id)
    refute res.error?, "got: #{res.content.first[:text]}"
    body = JSON.parse(res.content.first[:text])
    assert_equal "Pool", body["meta"]["branch"]
    assert_equal 2, body["data"].length
    row = body["data"].first
    assert row.key?("platz"), "Tabellenzeile braucht platz"
    assert row.key?("punkte")
    assert row.key?("partien"), "Pool-Tabelle hat partien-Spalte"
    assert_equal [1, 2], body["data"].map { |r| r["platz"] }.sort
  end

  # AC-1: Disziplin ohne Standings-Methode (Kegel) → freundlicher Hinweis, kein Crash.
  test "AC-1: Kegel-Liga → note statt Crash, leere data" do
    skip "NBV fixtures missing" unless @nbv
    res = call(league_id: @kegel_league.id)
    refute res.error?
    body = JSON.parse(res.content.first[:text])
    assert_equal [], body["data"]
    assert body["meta"]["note"].to_s.match?(/nicht.*berechnet|Kegel|öffentliche/i), "got note: #{body["meta"]["note"]}"
  end

  # AC-4: Liga einer anderen Region → Reject (kein Cross-Region-Leak).
  test "AC-4: fremde Region → Region-Scope-Reject" do
    skip "NBV fixtures missing" unless @nbv
    res = call(league_id: @foreign.id)
    assert res.error?
    assert_match(/gehört nicht zur Region/i, res.content.first[:text])
  end

  test "AC-4: unbekannte league_id → freundlicher Fehler" do
    res = call(league_id: 999_999_999)
    assert res.error?
    assert_match(/nicht gefunden/i, res.content.first[:text])
  end

  # AC-5: public_url ist — falls baubar — ein echter sb_spielplan-Link, nie Müll/halluziniert.
  test "AC-5: public_url im Tool-Output ist echter Link oder abwesend (kein billard.de)" do
    skip "NBV fixtures missing" unless @nbv
    res = call(league_id: @league.id, server_context: {cc_region: "NBV", user_id: users(:system_admin).id})
    body = JSON.parse(res.content.first[:text])
    pub = body["meta"]["public_url"]
    assert(pub.nil? || pub.match?(%r{sb_spielplan\.php\?p=}), "public_url muss echter Link oder abwesend sein, war: #{pub.inspect}")
    refute_match(/billard\.de/, res.content.first[:text])
  end

  # AC-5: Link-Konstruktion fixture-unabhängig beweisen (echter ndbv-Link) + Müll-Guard.
  test "AC-5: public_league_url_from baut sb_spielplan-Link und guardet gegen fehlende Teile" do
    base = McpServer::Tools::BaseTool
    assert_equal "https://ndbv.de/sb_spielplan.php?p=20--2025/2026-327",
      base.public_league_url_from(base: "https://ndbv.de/", fed: 20, season: "2025/2026", cc_id: 327)
    assert_nil base.public_league_url_from(base: nil, fed: 20, season: "2025/2026", cc_id: 327)
    assert_nil base.public_league_url_from(base: "https://ndbv.de/", fed: nil, season: "2025/2026", cc_id: 327)
    assert_nil base.public_league_url_from(base: "https://ndbv.de/", fed: 20, season: "2025/2026", cc_id: nil)
  end

  # source (D-40-1) rechte-gegated: cc_write_access? → Quelle, sonst "".
  test "source nur für cc_write_access?-User" do
    skip "user fixtures missing" unless users(:system_admin) && users(:valid)
    writer = call(league_id: @league.id, server_context: {cc_region: "NBV", user_id: users(:system_admin).id})
    reader = call(league_id: @league.id, server_context: {cc_region: "NBV", user_id: users(:valid).id})
    assert_equal McpServer::Tools::BaseTool::SOURCE_NOTES[:db_mirror],
      JSON.parse(writer.content.first[:text])["meta"]["source"]
    assert_equal "", JSON.parse(reader.content.first[:text])["meta"]["source"]
  end

  test "in BASE_READ_TOOLS registriert + über ToolRegistry sichtbar" do
    assert_includes McpServer::RoleToolMap::BASE_READ_TOOLS, :LeagueStandings
    assert_equal "cc_league_standings", McpServer::Tools::LeagueStandings.tool_name
    assert_includes McpServer::ToolRegistry.tool_classes_for(users(:valid)), McpServer::Tools::LeagueStandings
  end
end
