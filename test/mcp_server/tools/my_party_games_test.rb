# frozen_string_literal: true

require "test_helper"

# Plan 45-03: cc_my_party_games — self-scoped Liga-Einzelpartien (PartyGame.player_a/b_id),
# alle Spieltage in EINER Antwort, scopebar je Liga. Muster wie cc_my_results.
class McpServer::Tools::MyPartyGamesTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    McpServer::CcSession.reset!
    @user = User.create!(email: "mypg_user@test.de", password: "password123")
    @player = Player.create!(region: regions(:nbv), lastname: "PGtest", firstname: "Spieler")
    @opp_player = Player.create!(region: regions(:nbv), lastname: "Gegner", firstname: "Otto")
    @user.update!(player_id: @player.id)
    @ctx = {user_id: @user.id}

    @season = seasons(:current)
    @pool = Branch.create!(name: "Pool")
    @league = League.create!(name: "P4503PG Liga", shortname: "P4503PG",
      organizer: regions(:nbv), season: @season, discipline: @pool, cc_id: 945_310)
    @ta = LeagueTeam.create!(league: @league, name: "P4503PG A")
    @tb = LeagueTeam.create!(league: @league, name: "P4503PG B")
    # zwei Spieltage; in @p1 ist der Spieler player_a, in @p2 player_b.
    @p1 = Party.create!(league: @league, league_team_a: @ta, league_team_b: @tb, day_seqno: 1, date: 10.days.ago)
    @p2 = Party.create!(league: @league, league_team_a: @tb, league_team_b: @ta, day_seqno: 2, date: 3.days.ago)
    @g1 = PartyGame.create!(party: @p1, seqno: 1, discipline: @pool,
      player_a: @player, player_b: @opp_player, data: {"result" => {"Ergebnis" => "1:0"}})
    @g2 = PartyGame.create!(party: @p2, seqno: 3, discipline: @pool,
      player_a: @opp_player, player_b: @player, data: {"result" => {"Ergebnis" => "0:1"}})
  end

  teardown { ENV["CARAMBUS_MCP_MOCK"] = nil }

  def call(**kw)
    McpServer::Tools::MyPartyGames.call(server_context: @ctx, **kw)
  end

  def body(res)
    JSON.parse(res.content.first[:text])
  end

  test "AC-2: alle Einzelpartien quer über Spieltage in EINER Antwort" do
    b = body(call)
    pids = b["data"].map { |r| r["party_id"] }
    assert_includes pids, @p1.id
    assert_includes pids, @p2.id
    assert_equal 2, b["data"].length
    assert_equal @player.fullname, b["meta"]["player"]
  end

  test "AC-2: Gegner korrekt aufgelöst (player_a vs player_b) + Ergebnis" do
    rows = body(call)["data"]
    r1 = rows.find { |r| r["party_id"] == @p1.id } # Spieler = player_a
    r2 = rows.find { |r| r["party_id"] == @p2.id } # Spieler = player_b
    assert_equal "Gegner, Otto", r1["opponent"]
    assert_equal "Gegner, Otto", r2["opponent"]
    assert_equal({"Ergebnis" => "1:0"}, r1["result"])
  end

  test "AC-2: league_id grenzt auf eine Liga ein" do
    other = League.create!(name: "P4503PG L2", shortname: "P4503PG2",
      organizer: regions(:nbv), season: @season, discipline: @pool, cc_id: 945_311)
    ota = LeagueTeam.create!(league: other, name: "x")
    otb = LeagueTeam.create!(league: other, name: "y")
    op = Party.create!(league: other, league_team_a: ota, league_team_b: otb, day_seqno: 1, date: 1.day.ago)
    PartyGame.create!(party: op, seqno: 1, discipline: @pool, player_a: @player, player_b: @opp_player, data: {})

    only = body(call(league_id: @league.id))["data"].map { |r| r["party_id"] }
    assert_includes only, @p1.id
    assert_not_includes only, op.id
  end

  test "AC-3: nicht verknüpfter User → cc_link_my_player-Hinweis" do
    @user.update!(player_id: nil)
    res = call
    refute res.error?
    assert_match(/cc_link_my_player/i, res.content.first[:text])
  end

  test "Registrierung in BASE_READ_TOOLS + ToolRegistry" do
    assert_includes McpServer::RoleToolMap::BASE_READ_TOOLS, :MyPartyGames
    assert_equal "cc_my_party_games", McpServer::Tools::MyPartyGames.tool_name
    assert_includes McpServer::ToolRegistry.tool_classes_for(@user), McpServer::Tools::MyPartyGames
  end
end
