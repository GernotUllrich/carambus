# frozen_string_literal: true

require "test_helper"

# Plan 26-01: Vereinsauswahl für die Meldeliste eines Region-Turniers.
# Reihenfolge: Vereine mit gemeldeten Teilnehmern → Austragungsort-Verein → Rest alphabetisch.
class TournamentsHelperTest < ActionView::TestCase
  include TournamentsHelper

  setup do
    @tournament = tournaments(:local)
    @region = @tournament.organizer
    assert @region.is_a?(Region), "Fixture-Vorbedingung: Region-Turnier"
  end

  def club_in_region(name)
    Club.create!(name: name, shortname: name.gsub(/\s/, "")[0, 8], region_id: @region.id)
  end

  test "liefert die Vereine der Region alphabetisch, wenn nichts priorisiert ist" do
    zeta = club_in_region("Zeta Club")
    alpha = club_in_region("Alpha Club")

    result = entry_list_clubs_for(@tournament)
    ids = result.map(&:last)

    assert_includes ids, alpha.id
    assert_includes ids, zeta.id
    assert_operator ids.index(alpha.id), :<, ids.index(zeta.id), "alphabetisch: Alpha vor Zeta"
    assert_equal result.map(&:last).uniq, result.map(&:last), "keine Dubletten"
  end

  test "Verein mit gemeldetem Teilnehmer steht vorn" do
    _alpha = club_in_region("Alpha Club")
    zeta = club_in_region("Zeta Club")

    player = Player.create!(lastname: "MUSTER", firstname: "Max", fl_name: "M. Muster")
    SeasonParticipation.create!(player: player, club: zeta, season: @tournament.season)
    @tournament.seedings.create!(player_id: player.id, position: 1)

    ids = entry_list_clubs_for(@tournament).map(&:last)

    assert_equal zeta.id, ids.first, "Verein mit Meldung muss vor dem alphabetischen Rest stehen"
  end

  test "Austragungsort-Verein steht vor dem alphabetischen Rest" do
    _alpha = club_in_region("Alpha Club")
    host = club_in_region("Zeta Host Club")

    location = Location.create!(name: "Testhalle 26", organizer: @region)
    location.clubs << host
    @tournament.update!(location_id: location.id)

    ids = entry_list_clubs_for(@tournament).map(&:last)

    assert_equal host.id, ids.first, "Austragungsort-Verein muss vorn stehen"
  end

  test "Meldung schlaegt Austragungsort" do
    host = club_in_region("Aaa Host Club")
    seeded = club_in_region("Zzz Seeded Club")

    location = Location.create!(name: "Testhalle 26b", organizer: @region)
    location.clubs << host
    @tournament.update!(location_id: location.id)

    player = Player.create!(lastname: "MELDER", firstname: "Mia", fl_name: "M. Melder")
    SeasonParticipation.create!(player: player, club: seeded, season: @tournament.season)
    @tournament.seedings.create!(player_id: player.id, position: 1)

    ids = entry_list_clubs_for(@tournament).map(&:last)

    assert_equal seeded.id, ids.first, "Verein mit Meldung vor Austragungsort-Verein"
    assert_equal host.id, ids.second, "Austragungsort-Verein danach"
  end

  test "leeres Array, wenn keine Region bestimmbar ist" do
    club_tournament = Tournament.create!(
      title: "Club-Turnier 26", season: @tournament.season,
      organizer: clubs(:bcw), date: Time.current
    )

    assert_equal [], entry_list_clubs_for(club_tournament)
  end
end
