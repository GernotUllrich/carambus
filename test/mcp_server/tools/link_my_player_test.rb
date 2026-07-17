# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/mcp_server/tools/base_tool"
Dir[Rails.root.join("lib/mcp_server/tools/*.rb")].each { |f| require f }

# Phase 35-01: cc_link_my_player — Self-Service-Verknüpfung User↔Player (dbu_nr/ba_id, region-scoped).
class LinkMyPlayerTest < ActiveSupport::TestCase
  setup do
    # Region, die resolve_own_player tatsaechlich aufloest (effective_cc_region).
    region_shortname = McpServer::Tools::BaseTool.effective_cc_region({cc_region: "NBV"}).to_s.upcase
    @region = Region.find_by("UPPER(shortname) = ?", region_shortname)
    skip "Region #{region_shortname} nicht in Test-DB" if @region.nil?

    @user = User.create!(email: "lmp_user@test.de", password: "password123")
    @other = User.create!(email: "lmp_other@test.de", password: "password123")
    @player_dbu = Player.create!(region_id: @region.id, lastname: "Linktest", firstname: "DBU", dbu_nr: 9_900_001)
    @player_ba = Player.create!(region_id: @region.id, lastname: "Linktest", firstname: "BA", ba_id: 9_900_002)
    @ctx = {user_id: @user.id, cc_region: region_shortname}
  end

  def link(**kw)
    McpServer::Tools::LinkMyPlayer.call(server_context: @ctx, **kw)
  end

  test "nicht angemeldet → Fehler" do
    res = McpServer::Tools::LinkMyPlayer.call(server_context: {user_id: nil}, dbu_nr: 9_900_001, armed: true)
    assert res.error?
  end

  test "armed:false → Probelauf, player_id bleibt nil" do
    res = link(dbu_nr: 9_900_001, armed: false)
    assert_not res.error?
    assert_match(/Probelauf/, res.content.first[:text])
    assert_nil @user.reload.player_id
  end

  test "armed:true via dbu_nr → user.player gesetzt" do
    res = link(dbu_nr: 9_900_001, armed: true)
    assert_not res.error?
    assert_equal @player_dbu.id, @user.reload.player_id
    assert_equal @player_dbu, @user.player
  end

  test "ba_id-Fallback wenn dbu_nr leer" do
    res = link(ba_id: 9_900_002, armed: true)
    assert_not res.error?
    assert_equal @player_ba.id, @user.reload.player_id
  end

  test "keine Nummer matcht → Fehler, kein Write" do
    res = link(dbu_nr: 1_234_567, armed: true)
    assert res.error?
    assert_nil @user.reload.player_id
  end

  test "Player schon bei anderem User → Ablehnung, kein Write" do
    @other.update!(player_id: @player_dbu.id)
    res = link(dbu_nr: 9_900_001, armed: true)
    assert res.error?
    assert_match(/anderen Konto/, res.content.first[:text])
    assert_nil @user.reload.player_id
  end

  test "bereits verknüpft → idempotenter Hinweis (kein Fehler)" do
    @user.update!(player_id: @player_dbu.id)
    res = link(dbu_nr: 9_900_001, armed: true)
    assert_not res.error?
    assert_match(/bereits/, res.content.first[:text])
  end
end
