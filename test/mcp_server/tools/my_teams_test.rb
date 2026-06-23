# frozen_string_literal: true

require "test_helper"

# Plan 45-03: cc_my_teams — self-scoped Mannschafts-/Liga-Zugehörigkeit (LeagueTeam via
# Player#seedings) + nächste Party. Muster wie cc_my_tournaments (current_player-Gate).
class McpServer::Tools::MyTeamsTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    McpServer::CcSession.reset!
    @user = User.create!(email: "myteams_user@test.de", password: "password123")
    @player = Player.create!(region: regions(:nbv), lastname: "Teamtest", firstname: "Spieler")
    @user.update!(player_id: @player.id)
    @ctx = {user_id: @user.id}

    @season = seasons(:current)
    @pool = Branch.create!(name: "Pool")
    @league = League.create!(name: "P4503 Pool Liga", shortname: "P4503-PL",
      organizer: regions(:nbv), season: @season, discipline: @pool, cc_id: 945_301)
    @team = LeagueTeam.create!(league: @league, name: "P4503 My Team")
    @opp = LeagueTeam.create!(league: @league, name: "P4503 Gegner")
    Seeding.create!(player: @player, league_team: @team)
  end

  teardown { ENV["CARAMBUS_MCP_MOCK"] = nil }

  def call(**kw)
    McpServer::Tools::MyTeams.call(server_context: @ctx, **kw)
  end

  def body(res)
    JSON.parse(res.content.first[:text])
  end

  test "AC-1: listet meine Mannschaft mit Liga/Disziplin/Saison" do
    res = call
    refute res.error?, "got: #{res.content.first[:text]}"
    b = body(res)
    row = b["data"].find { |r| r["team_id"] == @team.id }
    assert row, "eigene Mannschaft muss erscheinen"
    assert_equal "P4503 Pool Liga", row["league"]
    assert_equal @league.id, row["league_id"]
    assert_equal @season.name, row["season"]
    assert_equal @player.fullname, b["meta"]["player"]
  end

  test "AC-1: nächste Party (date>=heute) wird gezeigt, Gegner aufgelöst" do
    p = Party.create!(league: @league, league_team_a: @team, league_team_b: @opp,
      day_seqno: 1, date: 30.days.from_now)
    row = body(call)["data"].find { |r| r["team_id"] == @team.id }
    assert row["next_party"], "next_party erwartet"
    assert_equal p.id, row["next_party"]["party_id"]
    assert_equal "P4503 Gegner", row["next_party"]["gegner"]
  end

  test "AC-1: vergangene Party zählt NICHT als nächste Party" do
    Party.create!(league: @league, league_team_a: @team, league_team_b: @opp,
      day_seqno: 1, date: 30.days.ago)
    row = body(call)["data"].find { |r| r["team_id"] == @team.id }
    assert_nil row["next_party"]
  end

  test "Default = aktuelle Saison; all_seasons:true zeigt auch alte Saison" do
    old = Season.find_or_create_by!(name: "2014/2015")
    skip "old == current" if old.id == @season.id
    ol = League.create!(name: "P4503 Old", shortname: "P4503-OLD",
      organizer: regions(:nbv), season: old, discipline: @pool, cc_id: 945_302)
    ot = LeagueTeam.create!(league: ol, name: "P4503 Old Team")
    Seeding.create!(player: @player, league_team: ot)

    default_ids = body(call)["data"].map { |r| r["team_id"] }
    assert_includes default_ids, @team.id
    assert_not_includes default_ids, ot.id, "alte Saison im Default ausgeschlossen"

    all_ids = body(call(all_seasons: true))["data"].map { |r| r["team_id"] }
    assert_includes all_ids, ot.id
  end

  test "AC-3: nicht verknüpfter User → cc_link_my_player-Hinweis" do
    @user.update!(player_id: nil)
    res = call
    refute res.error?
    assert_match(/cc_link_my_player/i, res.content.first[:text])
  end

  test "source gating (D-40-1) + Registrierung in BASE_READ_TOOLS" do
    assert_equal "", body(call)["source"] # player-User ohne cc_write_access
    @user.update!(role: :system_admin)
    assert_equal McpServer::Tools::BaseTool::SOURCE_NOTES[:db_mirror], body(call)["source"]
    assert_includes McpServer::RoleToolMap::BASE_READ_TOOLS, :MyTeams
    assert_equal "cc_my_teams", McpServer::Tools::MyTeams.tool_name
    assert_includes McpServer::ToolRegistry.tool_classes_for(@user), McpServer::Tools::MyTeams
  end
end
