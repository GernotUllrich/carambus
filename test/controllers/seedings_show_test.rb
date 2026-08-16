# frozen_string_literal: true

require "test_helper"

# Detailseite eines Seedings.
#
# Hintergrund: die Seite rief @seeding.tournament.title ungeschuetzt auf. Ein
# Seeding haengt aber entweder an einem Turnier ODER an einer Mannschaft
# (Seeding#exactly_one_association, `belongs_to :tournament, optional: true`).
# In Produktion warfen dadurch 69.660 Liga-Seedings 500 statt einer Seite;
# weitere 2.017 Records ohne Player scheiterten eine Zeile darueber.
class SeedingsShowTest < ActionDispatch::IntegrationTest
  setup do
    @player = players(:jaspers)
  end

  test "Seeding am Turnier zeigt den Turniertitel" do
    seeding = seedings(:wc_2024_jaspers)

    get seeding_path(seeding)

    assert_response :success
    assert_match seeding.tournament.title, response.body
  end

  test "Seeding an einer Mannschaft zeigt das Team statt 500" do
    seeding = Seeding.create!(player: @player, league_team: league_teams(:team_alpha), position: 1)

    get seeding_path(seeding)

    assert_response :success
    assert_match "Team Alpha", response.body
    assert_match "League team", response.body
  end

  test "Seeding ohne Player rendert trotzdem" do
    seeding = seedings(:wc_2024_jaspers)
    seeding.update_column(:player_id, nil)

    get seeding_path(seeding)

    assert_response :success
  end

  test "Seeding ohne Turnier und ohne Team rendert trotzdem" do
    seeding = seedings(:wc_2024_jaspers)
    seeding.update_columns(tournament_id: nil, tournament_type: nil)

    get seeding_path(seeding)

    assert_response :success
  end
end
