# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/mcp_server/tools/base_tool"
Dir[Rails.root.join("lib/mcp_server/tools/*.rb")].each { |f| require f }

# Phase 35-02: cc_my_tournaments — Mein-Billard read-only, self-scoped via current_user.player.
class MyTournamentsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "myt_user@test.de", password: "password123")
    @player = Player.create!(region: regions(:nbv), lastname: "Meintest", firstname: "Turnier")
    @user.update!(player_id: @player.id)
    @ctx = {user_id: @user.id}
  end

  def call(**kw)
    McpServer::Tools::MyTournaments.call(server_context: @ctx, **kw)
  end

  test "verknüpfter Spieler sieht eigene Turniere" do
    t = tournaments(:local)
    Seeding.create!(player: @player, tournament: t, rank: 1)
    res = call
    assert_not res.error?
    body = JSON.parse(res.content.first[:text])
    ids = body["data"].map { |r| r["tournament_id"] }
    assert_includes ids, t.id
    assert_equal @player.fullname, body["meta"]["player"]
  end

  test "self-scoped: fremde Seedings tauchen NICHT auf" do
    mine = tournaments(:local)
    theirs = tournaments(:imported)
    other = Player.create!(region: regions(:nbv), lastname: "Fremd", firstname: "Spieler")
    Seeding.create!(player: @player, tournament: mine)
    Seeding.create!(player: other, tournament: theirs)
    res = call
    body = JSON.parse(res.content.first[:text])
    ids = body["data"].map { |r| r["tournament_id"] }
    assert_includes ids, mine.id
    assert_not_includes ids, theirs.id
  end

  test "nicht verknüpfter User → Gate-Hinweis (kein Fehler, keine Daten)" do
    @user.update!(player_id: nil)
    res = call
    assert_not res.error?
    assert_match(/cc_link_my_player/i, res.content.first[:text])
  end

  test "nicht angemeldet → Fehler" do
    res = McpServer::Tools::MyTournaments.call(server_context: {user_id: nil})
    assert res.error?
  end
end
