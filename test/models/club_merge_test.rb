# frozen_string_literal: true

require "test_helper"

# Club#merge_clubs (Betreiber 2026-10-20, Dublette BC GT Buer): nach dem Zusammenfuehren zeigt kein
# Verweis ins Leere, und offizielle Daten (DBU-Vereinsnummer, Vereinsname) haben Vorrang.
class ClubMergeTest < ActiveSupport::TestCase
  setup do
    # Nachgestellt: Master traegt die Daten des Spielbetriebs (Spieler, Mannschaften), das
    # Duplikat die offiziellen (DBU-Nummer, Name aus der ClubCloud).
    @master = Club.create!(name: "BC Testtisch 1931 e.V. Ortsteil", shortname: "BC TT",
      ba_id: 998_777_001, cc_id: 9_271, synonyms: "BC TT\nBC Testtisch 1931 e.V. Ortsteil")
    @slave = Club.create!(name: "Billard-Club Testtisch 1931 e.V.", shortname: "BC TT",
      dbu_nr: 9_271, cc_id: 9_271, logo: "https://example.test/tt.png",
      synonyms: "Billard-Club Testtisch 1931 e.V.\nBC TT")
    @player = Player.create!(firstname: "Test-Merge", lastname: "Spieler")
    @season = seasons(:current)
  end

  def merge!
    @master.merge_clubs([@slave.id], force_merge: true)
  end

  test "Verweise des Duplikats zeigen danach auf den Master" do
    @player.update_columns(club_id: @slave.id)
    location = Location.create!(name: "Test-Merge-Ort")
    # locations.club_id ist im Modell ignoriert — nur per SQL setzbar
    Location.where(id: location.id).update_all(club_id: @slave.id)
    ClubLocation.create!(club: @slave, location: location)
    team = league_teams(:team_alpha)
    team.update_columns(club_id: @slave.id)
    seeding = Seeding.create!(tournament: tournaments(:local), player: @player, position: 1,
      data: {"club_id" => @slave.id})
    sp = SeasonParticipation.create!(player: @player, season: @season, club: @slave)

    merge!

    assert_not Club.exists?(@slave.id), "Duplikat geloescht"
    assert_equal @master.id, @player.reload.club_id, "players.club_id"
    assert_equal @master.id, Location.where(id: location.id).pick(:club_id), "locations.club_id"
    assert_equal [@master.id], ClubLocation.where(location_id: location.id).pluck(:club_id), "club_locations"
    assert_equal @master.id, team.reload.club_id, "league_teams"
    assert_equal @master.id, seeding.reload.data["club_id"], "seeding.data club_id (Meldelisten-Verein)"
    assert_equal @master.id, sp.reload.club_id, "season_participations"
  end

  test "gemeinsamer Spielort: doppelte Zuordnung wird geloescht, nicht dupliziert" do
    location = Location.create!(name: "Test-Merge-Gemeinsam")
    ClubLocation.create!(club: @master, location: location)
    ClubLocation.create!(club: @slave, location: location)

    merge!

    assert_equal [@master.id], ClubLocation.where(location_id: location.id).pluck(:club_id)
  end

  test "offizielle Daten des Duplikats haben Vorrang: dbu_nr, Name, Logo; alter Name bleibt Synonym" do
    merge!
    @master.reload

    assert_equal 9_271, @master.dbu_nr
    assert_equal "Billard-Club Testtisch 1931 e.V.", @master.name
    assert_equal "https://example.test/tt.png", @master.logo
    assert_includes @master.synonyms.split("\n"), "BC Testtisch 1931 e.V. Ortsteil"
    assert_equal 998_777_001, @master.ba_id, "ba_id ist irrelevant und bleibt unberuehrt"
  end

  test "ist der Master selbst offiziell, behaelt er Name und dbu_nr (Gegenprobe)" do
    @master.update_columns(dbu_nr: 1_111, name: "Offizieller Master e.V.")
    merge!
    @master.reload

    assert_equal 1_111, @master.dbu_nr
    assert_equal "Offizieller Master e.V.", @master.name
  end
end
