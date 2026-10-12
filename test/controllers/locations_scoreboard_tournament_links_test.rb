# frozen_string_literal: true

require "test_helper"

# 2026-10-13 (Betreiber): In ?sb_state=tournament fuehrte ein Klick auf einen Tisch nicht auf
# sein Scoreboard, in ?sb_state=tables schon. Turniere mit manual_assignment — darunter JEDES
# App-Turnier (LocalTournamentCreator) — verlinkten jeden Tisch auf `placement`, die
# Paarungsauswahl. Die baut sich aus `tournament.games`; App-Partien haengen an keinem Turnier,
# die Auswahl war leer. Ein Tisch MIT laufendem Spiel gehoert aufs Scoreboard, wie in "tables".
class LocationsScoreboardTournamentLinksTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
    @location = locations(:one)
    @table = tables(:one)
    discipline = Discipline.create!(name: "ZZ Biathlon Links #{SecureRandom.hex(2)}", table_kind_id: @table.table_kind_id)
    @tournament = Tournament.create!(
      title: "ZZ App-Turnier Links", season: seasons(:current), organizer: regions(:nbv),
      discipline: discipline, location: @location, manual_assignment: true, date: Date.current
    )
    TournamentMonitor.create!(tournament: @tournament)
    @tm = table_monitors(:one)
  end

  test "Tisch mit laufendem Spiel verlinkt aufs Scoreboard" do
    game = Game.create!(data: {"external_id" => "app-links-1"})
    @tm.update_columns(game_id: game.id, state: "playing")

    get location_path(@location, sb_state: "tournament")

    assert_response :success
    assert_select "a#table_monitor_#{@table.id}[href=?]", table_monitor_path(@tm)
  end

  test "freier Tisch fuehrt weiter zur Platzierung" do
    @tm.update_columns(game_id: nil, state: "ready")

    get location_path(@location, sb_state: "tournament")

    assert_response :success
    assert_select "a#table_monitor_#{@table.id}[href*=?]", "placement"
  end
end
