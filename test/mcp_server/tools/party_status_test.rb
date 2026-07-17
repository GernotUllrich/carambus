# frozen_string_literal: true

require "test_helper"

# Plan 47-03: cc_party_status — Read. Zustand + Mannschaftsergebnis + next_step + Web-Link.
class McpServer::Tools::PartyStatusTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    McpServer::CcSession.reset!
    @nbv = regions(:nbv)
    @season = seasons(:current)
    @pool = Branch.create!(name: "Pool")
    @league = League.create!(name: "P4703S Pool Liga", shortname: "P4703S-PL",
      organizer: @nbv, season: @season, discipline: @pool, cc_id: 947_031)
    @a = LeagueTeam.create!(league: @league, name: "P4703S Team A")
    @b = LeagueTeam.create!(league: @league, name: "P4703S Team B")
    @party = Party.create!(league: @league, league_team_a: @a, league_team_b: @b,
      host_league_team: @a, day_seqno: 1, date: Date.new(2026, 3, 20), team_size: 4, data: {})
    @ctx = {cc_region: "NBV"}
  end

  teardown { ENV["CARAMBUS_MCP_MOCK"] = nil }

  def call(**kw)
    McpServer::Tools::PartyStatus.call(server_context: @ctx, **kw)
  end

  def body(res)
    JSON.parse(res.content.first[:text])
  end

  test "AC-2: nicht gestartet (kein PartyMonitor) → started false + next_step öffnen" do
    res = call(party_id: @party.id)
    refute res.error?, "got: #{res.content.first[:text]}"
    b = body(res)
    assert_equal false, b["started"]
    assert_nil b["state"]
    assert_equal [0, 0], b["intermediate_result"]
    assert_match(/öffnen|cc_start_party_day/i, b["next_step"])
    assert b["web_url"].to_s.include?("party_monitor")
  end

  test "AC-2: gestartet → state + next_step für playing_round" do
    PartyMonitor.create!(party: @party, state: "playing_round", data: {"rows" => []})
    res = call(party_id: @party.id)
    refute res.error?
    b = body(res)
    assert_equal true, b["started"]
    assert_equal "playing_round", b["state"]
    assert_match(/Ergebnisse im Web/i, b["next_step"])
  end

  test "AC-2: closed → Ergebnis aus data.result.game_points" do
    PartyMonitor.create!(party: @party, state: "closed",
      data: {"result" => {"game_points" => "2:4", "match_points" => "0:0"}})
    res = call(party_id: @party.id)
    refute res.error?
    b = body(res)
    assert_equal "closed", b["state"]
    assert_equal "2:4", b.dig("result", "game_points")
    assert_match(/abgeschlossen.*2:4/i, b["next_step"])
  end

  test "nicht auflösbare Party → Fehler" do
    res = call(party_id: 999_999)
    assert res.error?
    assert_match(/Party nicht gefunden/i, res.content.first[:text])
  end
end
