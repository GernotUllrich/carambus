# frozen_string_literal: true

require "test_helper"

# Plan 45-02: cc_league_schedule — Spielplan/Paarungen einer Liga (League#schedule_by_rounds).
class McpServer::Tools::LeagueScheduleTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    McpServer::CcSession.reset!
    @nbv = regions(:nbv)
    @season = seasons(:current)
    @pool = Branch.create!(name: "Pool")
    @league = League.create!(name: "P4502S Pool Liga", shortname: "P4502S-PL",
      organizer: @nbv, season: @season, discipline: @pool, cc_id: 945_220)
    @a = LeagueTeam.create!(league: @league, name: "P4502S Team A")
    @b = LeagueTeam.create!(league: @league, name: "P4502S Team B")
    @p1 = Party.create!(league: @league, league_team_a: @a, league_team_b: @b,
      host_league_team: @a, day_seqno: 1, date: Date.new(2026, 1, 10), data: {"result" => "5:3"})
    @p2 = Party.create!(league: @league, league_team_a: @b, league_team_b: @a,
      host_league_team: @b, day_seqno: 2, date: Date.new(2026, 2, 14), data: {})
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    [@p1, @p2, @a, @b, @league, @pool].compact.each { |r| r.destroy if r&.persisted? }
  end

  def body_of(resp)
    JSON.parse(resp.content.first[:text])
  end

  test "AC-2: Paarungen mit Teams/Datum/Ergebnis + gegateter Quelle + public_url" do
    skip "fixtures missing" unless @nbv && users(:system_admin)
    resp = McpServer::Tools::LeagueSchedule.call(
      league_id: @league.id, server_context: {cc_region: "NBV", user_id: users(:system_admin).id}
    )
    refute resp.error?, "got: #{resp.content.first[:text]}"
    body = body_of(resp)
    assert_equal 2, body["meta"]["party_count"]
    parties = body["rounds"].flat_map { |r| r["parties"] }
    played = parties.find { |p| p["party_id"] == @p1.id }
    assert_equal "P4502S Team A", played["team_a"]
    assert_equal "P4502S Team B", played["team_b"]
    assert_equal "5:3", played["result"]
    assert played["date"].present?
    open_party = parties.find { |p| p["party_id"] == @p2.id }
    assert_nil open_party["result"]
    assert_equal McpServer::Tools::BaseTool::SOURCE_NOTES[:db_mirror], body["meta"]["source"]
    # public_url: falls baubar ein echter sb_spielplan-Link, nie Müll (Fixture ohne public_cc_url_base → ggf. abwesend).
    pub = body["meta"]["public_url"]
    if pub
      assert_match(%r{sb_spielplan\.php\?p=}, pub)
      refute_match(/billard\.de/, pub)
    end
  end

  test "AC-5: source leer für read-only, kein billard.de" do
    skip "fixtures missing" unless @nbv && users(:valid)
    resp = McpServer::Tools::LeagueSchedule.call(
      league_id: @league.id, server_context: {cc_region: "NBV", user_id: users(:valid).id}
    )
    assert_equal "", body_of(resp)["meta"]["source"]
    refute_match(/billard\.de/, resp.content.first[:text])
  end

  test "AC-4: Liga außerhalb der Region → Fehler" do
    skip "fixtures missing" unless @nbv && regions(:bbv)
    other = League.create!(name: "P4502S BBV", shortname: "P4502S-BBV",
      organizer: regions(:bbv), season: @season, discipline: @pool, cc_id: 945_221)
    resp = McpServer::Tools::LeagueSchedule.call(league_id: other.id, server_context: {cc_region: "NBV"})
    assert resp.error?
  ensure
    other&.destroy
  end

  test "Registrierung in BASE_READ_TOOLS + ToolRegistry" do
    assert_includes McpServer::RoleToolMap::BASE_READ_TOOLS, :LeagueSchedule
    assert_equal "cc_league_schedule", McpServer::Tools::LeagueSchedule.tool_name
    assert_includes McpServer::ToolRegistry.tool_classes_for(users(:valid)), McpServer::Tools::LeagueSchedule
  end
end
