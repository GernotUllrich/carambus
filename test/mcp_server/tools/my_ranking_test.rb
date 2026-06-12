# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/mcp_server/tools/base_tool"
Dir[Rails.root.join("lib/mcp_server/tools/*.rb")].each { |f| require f }

# Phase 35-02: cc_my_ranking — Mein-Billard read-only, self-scoped via current_user.player.
class MyRankingTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "myrk_user@test.de", password: "password123")
    @player = Player.create!(region: regions(:nbv), lastname: "Meintest", firstname: "Rangliste")
    @user.update!(player_id: @player.id)
    @ctx = {user_id: @user.id}
  end

  def call(**kw)
    McpServer::Tools::MyRanking.call(server_context: @ctx, **kw)
  end

  test "verknüpfter Spieler sieht eigene Rangliste" do
    PlayerRanking.create!(
      player: @player, discipline: disciplines(:one), region: regions(:nbv), season: seasons(:current),
      rank: 5, gd: 2.0, quote: 0.8, balls: 120, innings: 60
    )
    res = call
    assert_not res.error?
    body = JSON.parse(res.content.first[:text])
    assert_operator body["data"].length, :>=, 1
    assert_equal 5, body["data"].first["rank"]
    assert_equal @player.fullname, body["meta"]["player"]
  end

  test "nicht verknüpfter User → Gate-Hinweis (kein Fehler)" do
    @user.update!(player_id: nil)
    res = call
    assert_not res.error?
    assert_match(/cc_link_my_player/i, res.content.first[:text])
  end

  test "nicht angemeldet → Fehler" do
    res = McpServer::Tools::MyRanking.call(server_context: {user_id: nil})
    assert res.error?
  end
end
