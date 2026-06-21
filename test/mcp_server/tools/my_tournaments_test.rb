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

  test "placement = erspielte Platzierung aus data['result'] (Karambol-Key 'Rang')" do
    t = tournaments(:local)
    Seeding.create!(player: @player, tournament: t, position: 8,
      data: {"result" => {"Gesamtrangliste" => {"Rang" => 3, "GD" => "1,35"}}})
    body = JSON.parse(call.content.first[:text])
    row = body["data"].find { |r| r["tournament_id"] == t.id }
    assert_equal 3, row["placement"]
    assert_not row.key?("position"), "Setzposition darf nicht mehr im Output sein"
    assert_not row.key?("rank")
  end

  test "placement = erspielte Platzierung aus data['result'] (Snooker/Pool-Key 'Rank')" do
    t = tournaments(:local)
    Seeding.create!(player: @player, tournament: t, position: 19,
      data: {"result" => {"Gesamtrangliste" => {"Rank" => 19}}})
    body = JSON.parse(call.content.first[:text])
    row = body["data"].find { |r| r["tournament_id"] == t.id }
    assert_equal 19, row["placement"]
  end

  test "Dedup pro Turnier: Seeding mit Ergebnis gewinnt, keine Dublette" do
    t = tournaments(:local)
    Seeding.create!(player: @player, tournament: t, position: 17, data: {}) # verwaister Scrape-Rest
    Seeding.create!(player: @player, tournament: t, position: 8,
      data: {"result" => {"Gesamtrangliste" => {"Rang" => 2}}}) # maszgeblich
    body = JSON.parse(call.content.first[:text])
    rows = body["data"].select { |r| r["tournament_id"] == t.id }
    assert_equal 1, rows.size, "Turnier darf nur einmal erscheinen"
    assert_equal 2, rows.first["placement"]
  end

  test "placement faellt auf DB-Spalte rank zurueck (Monitor-Turnier ohne data['result'])" do
    t = tournaments(:local)
    Seeding.create!(player: @player, tournament: t, rank: 1, data: {})
    body = JSON.parse(call.content.first[:text])
    row = body["data"].find { |r| r["tournament_id"] == t.id }
    assert_equal 1, row["placement"]
  end
end
