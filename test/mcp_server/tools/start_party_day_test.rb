# frozen_string_literal: true

require "test_helper"

# Plan 47-03: cc_start_party_day — Thin-Bridge, öffnet den PartyMonitor + liefert
# Web-Link. Muster wie cc_prepare_tournament. Setup gespiegelt von set_party_lineup_test.
class McpServer::Tools::StartPartyDayTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    McpServer::CcSession.reset!
    # local_server? = Carambus.config.carambus_api_url.present? → für find-or-create true stubben.
    @orig_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test"

    @nbv = regions(:nbv)
    @season = seasons(:current)
    @pool = Branch.create!(name: "Pool")
    @league = League.create!(name: "P4703 Pool Liga", shortname: "P4703-PL",
      organizer: @nbv, season: @season, discipline: @pool, cc_id: 947_030)
    @a = LeagueTeam.create!(league: @league, name: "P4703 Team A")
    @b = LeagueTeam.create!(league: @league, name: "P4703 Team B")
    @party = Party.create!(league: @league, league_team_a: @a, league_team_b: @b,
      host_league_team: @a, day_seqno: 1, date: Date.new(2026, 3, 20), team_size: 4, data: {})

    @sw = User.create!(email: "p4703_sw@test.de", password: "password123", persona_grants: ["sportwart"])
    @sw.sportwart_disciplines << @pool
    @ctx = {cc_region: "NBV", user_id: @sw.id}
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    Carambus.config.carambus_api_url = @orig_api_url
  end

  def call(ctx: @ctx, **kw)
    McpServer::Tools::StartPartyDay.call(server_context: ctx, **kw)
  end

  def body(res)
    JSON.parse(res.content.first[:text])
  end

  test "AC-1: öffnet vorhandenen PartyMonitor + liefert Web-Link" do
    PartyMonitor.create!(party: @party, state: "seeding_mode", data: {})
    res = call(party_id: @party.id)
    refute res.error?, "got: #{res.content.first[:text]}"
    b = body(res)
    assert_equal true, b["ok"]
    assert_equal "seeding_mode", b["party_monitor_state"]
    assert b["web_url"].to_s.include?("party_monitor"), "web_url: #{b["web_url"].inspect}"
    assert_equal 1, PartyMonitor.where(party_id: @party.id).count, "kein Duplikat"
  end

  test "AC-1: nicht auflösbare Party → Fehler (resolve)" do
    res = call(party_id: 999_999)
    assert res.error?
    assert_match(/Party nicht gefunden/i, res.content.first[:text])
  end

  test "AC-1: ohne CC-Schreibrecht → Auth-Denial, kein Öffnen" do
    plain = User.create!(email: "p4703_plain@test.de", password: "password123")
    res = call(ctx: {cc_region: "NBV", user_id: plain.id}, party_id: @party.id)
    assert res.error?
    assert_match(/zuständig|Sportwart/i, res.content.first[:text])
    assert_equal 0, PartyMonitor.where(party_id: @party.id).count
  end

  test "AC-1: Erzeugung schlägt fehl (kein game_plan) → reason open_failed + web_url" do
    # Frische Party ohne PartyMonitor: create_party_monitor löst reset_party_monitor aus,
    # das ohne league.game_plan crasht (bekannter Runtime-Befund) → Opener fängt es ab.
    res = call(party_id: @party.id)
    refute res.error?
    b = body(res)
    assert_equal false, b["ok"]
    assert_equal "open_failed", b["reason"]
    assert b["web_url"].to_s.include?("party_monitor")
  end

  test "non-local-server → reason not_local_server + web_url (kein Öffnen)" do
    Carambus.config.carambus_api_url = nil
    PartyMonitor.where(party_id: @party.id).destroy_all
    res = call(party_id: @party.id)
    refute res.error?
    b = body(res)
    assert_equal false, b["ok"]
    assert_equal "not_local_server", b["reason"]
    assert_nil PartyMonitor.where(party_id: @party.id).first, "darf nichts erzeugen"
  end
end
