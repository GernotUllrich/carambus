# frozen_string_literal: true

require "test_helper"

# Plan 45-01: cc_list_leagues — Liga-Discovery (Pool-first).
# AC-2: listet die Pool-Ligen DER Region/Saison (inkl. Branch-Root-Ligen) mit
#       league_id/cc_id/branch/discipline/season/team_count + rechte-gegateter Quelle.
class McpServer::Tools::ListLeaguesTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    ENV["CC_FED_ID"] = nil
    ENV["CC_REGION"] = nil
    McpServer::CcSession.reset!

    @nbv = regions(:nbv)
    @season = seasons(:current)
    # Pool = Branch-Root (type=Branch). Reale Pool-Ligen hängen am Root (discipline_id=Pool),
    # NICHT an Sub-Disziplinen → testet die inklusive Branch-Auflösung.
    @pool = Branch.create!(name: "P45LL-Pool")
    @nineball = Discipline.create!(name: "P45LL-9Ball", super_discipline: @pool)
    @league = League.create!(name: "P45LL Pool Bezirksliga", shortname: "P45LL-PBL",
      organizer: @nbv, season: @season, discipline: @pool, cc_id: 945_201)
    @t1 = LeagueTeam.create!(league: @league, name: "P45LL Team A")
    @t2 = LeagueTeam.create!(league: @league, name: "P45LL Team B")
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    [@t1, @t2, @league, @nineball, @pool].compact.each { |r| r.destroy if r&.persisted? }
  end

  def row_for(body, league_id)
    body["data"].find { |r| r["league_id"] == league_id }
  end

  # AC-2 + inklusive Branch-Auflösung: discipline "Pool" findet die am Branch-Root hängende Liga.
  test "AC-2: discipline 'Pool' listet die region-/saison-gescopte Pool-Liga (Branch-Root)" do
    skip "NBV fixtures missing" unless @nbv
    response = McpServer::Tools::ListLeagues.call(
      discipline: "P45LL-Pool", server_context: {cc_region: "NBV"}
    )
    refute response.error?, "got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])

    assert_equal "NBV", body["meta"]["region"]
    assert_equal "P45LL-Pool", body["meta"]["branch"]
    assert_equal body["data"].length, body["meta"]["count"]

    row = row_for(body, @league.id)
    assert row, "Branch-Root-Liga (discipline_id=Pool) muss gelistet sein (inklusive Auflösung)"
    assert_equal 945_201, row["cc_id"]
    assert_equal "P45LL Pool Bezirksliga", row["name"]
    assert_equal "P45LL-Pool", row["branch"]
    assert row.key?("discipline_name")
    assert_equal @season.name, row["season"]
  end

  # AC-2: team_count korrekt.
  test "AC-2: team_count zählt die LeagueTeams" do
    skip "NBV fixtures missing" unless @nbv
    response = McpServer::Tools::ListLeagues.call(
      discipline: "P45LL-Pool", server_context: {cc_region: "NBV"}
    )
    body = JSON.parse(response.content.first[:text])
    row = row_for(body, @league.id)
    assert_equal 2, row["team_count"]
  end

  # AC-2: Quelle (D-40-1) rechte-gegated — nur für cc_write_access?-User, sonst "".
  test "AC-2: source nur für cc_write_access?-User (sonst leer)" do
    skip "NBV / user fixtures missing" unless @nbv && users(:system_admin) && users(:valid)

    writer = McpServer::Tools::ListLeagues.call(
      discipline: "P45LL-Pool", server_context: {cc_region: "NBV", user_id: users(:system_admin).id}
    )
    reader = McpServer::Tools::ListLeagues.call(
      discipline: "P45LL-Pool", server_context: {cc_region: "NBV", user_id: users(:valid).id}
    )
    assert_equal McpServer::Tools::BaseTool::SOURCE_NOTES[:db_mirror],
      JSON.parse(writer.content.first[:text])["meta"]["source"]
    assert_equal "", JSON.parse(reader.content.first[:text])["meta"]["source"]
  end

  # Registrierung: ListLeagues in BASE_READ_TOOLS → via ToolRegistry in MCP + Chat (eine Quelle, D-34-3).
  test "ListLeagues ist in BASE_READ_TOOLS registriert und über ToolRegistry sichtbar" do
    assert_includes McpServer::RoleToolMap::BASE_READ_TOOLS, :ListLeagues
    assert_equal "cc_list_leagues", McpServer::Tools::ListLeagues.tool_name
    classes = McpServer::ToolRegistry.tool_classes_for(users(:valid))
    assert_includes classes, McpServer::Tools::ListLeagues
  end

  test "missing Scenario-Config (server_context nil) → Diagnostic-Error" do
    response = McpServer::Tools::ListLeagues.call(server_context: nil)
    assert response.error?
    assert_match(/Scenario-Config-Fehler.*Carambus\.config\.context/i, response.content.first[:text])
  end

  test "unbekannte discipline → Error mit Vokabular-Hinweis" do
    skip "NBV fixtures missing" unless @nbv
    response = McpServer::Tools::ListLeagues.call(
      discipline: "Nonexistent-#{SecureRandom.hex(4)}", server_context: {cc_region: "NBV"}
    )
    assert response.error?
    assert_match(/nicht gefunden|Branch/i, response.content.first[:text])
  end

  test "force_refresh: true bleibt defensiv (kein Crash bei sync-Fehler)" do
    skip "NBV fixtures missing" unless @nbv
    region_cc = @nbv.region_cc
    if region_cc
      region_cc.stub(:sync_leagues, ->(**_) { raise StandardError, "stubbed sync failure" }) do
        response = McpServer::Tools::ListLeagues.call(
          discipline: "P45LL-Pool", server_context: {cc_region: "NBV"}, force_refresh: true
        )
        refute response.error?, "Tool muss gegen sync-Fehler defensiv sein"
      end
    else
      response = McpServer::Tools::ListLeagues.call(
        discipline: "P45LL-Pool", server_context: {cc_region: "NBV"}, force_refresh: true
      )
      refute response.error?
    end
  end
end
