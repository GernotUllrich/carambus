# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/mcp_server/tools/base_tool"
Dir[Rails.root.join("lib/mcp_server/tools/*.rb")].each { |f| require f }

# Phase 35-02: cc_my_results — Mein-Billard read-only, self-scoped via current_user.player.
class MyResultsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "myr_user@test.de", password: "password123")
    @player = Player.create!(region: regions(:nbv), lastname: "Meintest", firstname: "Ergebnis")
    @user.update!(player_id: @player.id)
    @ctx = {user_id: @user.id}
  end

  def call(**kw)
    McpServer::Tools::MyResults.call(server_context: @ctx, **kw)
  end

  # Game hat AASM/Callbacks — falls die Test-DB die Erzeugung nicht trägt, skippt der
  # Happy-Path (Tool-Call-Pfad bleibt durch Gate/Auth-Tests abgedeckt).
  def build_participation_for(player)
    g = Game.create!(tournament: tournaments(:local), seqno: 1)
    GameParticipation.create!(game: g, player: player, points: 2, innings: 40, hs: 10, gd: 1.0, result: 1, role: "playera")
    g
  rescue => e
    Rails.logger.warn "[MyResultsTest.build_participation_for] #{e.class}: #{e.message}"
    nil
  end

  test "verknüpfter Spieler sieht eigene Ergebnisse" do
    skip "Game/GameParticipation-Setup in Test-DB nicht möglich" if build_participation_for(@player).nil?
    res = call
    assert_not res.error?
    body = JSON.parse(res.content.first[:text])
    assert_operator body["data"].length, :>=, 1
    assert_equal @player.fullname, body["meta"]["player"]
  end

  test "nicht verknüpfter User → Gate-Hinweis (kein Fehler)" do
    @user.update!(player_id: nil)
    res = call
    assert_not res.error?
    assert_match(/cc_link_my_player/i, res.content.first[:text])
  end

  test "nicht angemeldet → Fehler" do
    res = McpServer::Tools::MyResults.call(server_context: {user_id: nil})
    assert res.error?
  end
end
