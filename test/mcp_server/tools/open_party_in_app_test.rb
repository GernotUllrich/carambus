# frozen_string_literal: true

require "test_helper"

# Plan 48-05: cc_open_party_in_app — Chat-Tool, liefert einen vorverbindenden App-Deeplink
# auf das carambus_app-"spieltag"-Schema. Setup gespiegelt von start_party_day_test.
class McpServer::Tools::OpenPartyInAppTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    McpServer::CcSession.reset!
    @orig_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test"

    @nbv = regions(:nbv)
    @season = seasons(:current)
    @pool = Branch.create!(name: "Pool")
    @league = League.create!(name: "P4805 Pool Liga", shortname: "P4805-PL",
      organizer: @nbv, season: @season, discipline: @pool, cc_id: 948_050)
    @a = LeagueTeam.create!(league: @league, name: "P4805 Team A")
    @b = LeagueTeam.create!(league: @league, name: "P4805 Team B")
    @party = Party.create!(league: @league, league_team_a: @a, league_team_b: @b,
      host_league_team: @a, day_seqno: 1, date: Date.new(2026, 3, 20), team_size: 4, cc_id: 95_001, data: {})

    @sw = User.create!(email: "p4805_sw@test.de", password: "password123", persona_grants: ["sportwart"])
    @sw.sportwart_disciplines << @pool
    @ctx = {cc_region: "NBV", user_id: @sw.id}
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    Carambus.config.carambus_api_url = @orig_api_url
  end

  def call(ctx: @ctx, **kw)
    McpServer::Tools::OpenPartyInApp.call(server_context: ctx, **kw)
  end

  def body(res)
    JSON.parse(res.content.first[:text])
  end

  test "AC-2: liefert App-Deeplink mit cb_party_id/cb_party_cc_id/cb_region + message" do
    res = call(party_id: @party.id)
    refute res.error?, "got: #{res.content.first[:text]}"
    b = body(res)
    assert_equal true, b["ok"]
    link = b["app_link"]
    assert_includes link, "cb_party_id=#{@party.id}"
    assert_includes link, "cb_party_cc_id=95001"
    assert_includes link, "cb_region=NBV"
    assert_includes b["message"], link
  end

  test "AC-2: nicht auflösbare Party → Fehler" do
    res = call(party_id: 999_999)
    assert res.error?
    assert_match(/Party nicht gefunden/i, res.content.first[:text])
  end

  test "AC-2: ohne CC-Schreibrecht → Auth-Denial" do
    plain = User.create!(email: "p4805_plain@test.de", password: "password123")
    res = call(ctx: {cc_region: "NBV", user_id: plain.id}, party_id: @party.id)
    assert res.error?
    assert_match(/zuständig|Sportwart/i, res.content.first[:text])
  end

  test "Registrierung: OpenPartyInApp ist Write-Tool (cc_write_access?-Personas)" do
    assert_includes McpServer::RoleToolMap::WRITE_TOOLS, :OpenPartyInApp
  end
end
