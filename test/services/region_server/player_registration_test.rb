# frozen_string_literal: true

require "test_helper"

# Plan 35-01: Characterization der geteilten Melde-Datenschicht.
#
# Diese Tests halten das VERHALTEN fest, das vor der Extraktion in
# TournamentsController#players_by_club und #add_player_by_dbu lag — inklusive der beiden
# Fallstricke, die im Ursprungscode auskommentiert waren: die Turniersaison (nicht
# Season.current_season) und die fortlaufende Position innerhalb einer Mehrfach-Eingabe.
class RegionServer::PlayerRegistrationTest < ActiveSupport::TestCase
  setup do
    @tournament = tournaments(:local)
    @season = @tournament.season
    @club = Club.create!(name: "Testverein 35", shortname: "TV35", region_id: 50_000_001)
    @alpha = Player.create!(lastname: "ALPHA", firstname: "Anna", fl_name: "A. Alpha", dbu_nr: "111111")
    @beta = Player.create!(lastname: "BETA", firstname: "Bert", fl_name: "B. Beta", dbu_nr: "222222")
    [@alpha, @beta].each { |pl| SeasonParticipation.create!(player: pl, club: @club, season: @season) }
  end

  # --- selectable_players -----------------------------------------------------

  test "selectable_players liefert die Vereinsspieler der Turniersaison" do
    rows = RegionServer::PlayerRegistration.selectable_players(tournament: @tournament, club_id: @club.id)

    assert_equal 2, rows.size
    assert_equal [@alpha.id, @beta.id].sort, rows.map { |r| r[:id] }.sort
    assert_equal [111_111, 222_222], rows.map { |r| r[:dbu_nr] }.sort
    assert rows.all? { |r| r[:label].present? }, "label muss gesetzt sein"
  end

  test "selectable_players ohne club_id liefert eine leere Liste" do
    assert_equal [], RegionServer::PlayerRegistration.selectable_players(tournament: @tournament, club_id: nil)
    assert_equal [], RegionServer::PlayerRegistration.selectable_players(tournament: @tournament, club_id: "")
  end

  test "selectable_players laesst bereits gemeldete Spieler weg" do
    @tournament.seedings.create!(player_id: @alpha.id, position: 1)

    rows = RegionServer::PlayerRegistration.selectable_players(tournament: @tournament, club_id: @club.id)

    refute_includes rows.map { |r| r[:id] }, @alpha.id
    assert_equal 1, rows.size
  end

  test "selectable_players sortiert nach label" do
    rows = RegionServer::PlayerRegistration.selectable_players(tournament: @tournament, club_id: @club.id)

    assert_equal rows.map { |r| r[:label] }.sort, rows.map { |r| r[:label] }
  end

  test "selectable_players filtert auf die Turniersaison, nicht auf die laufende" do
    other_season = Season.where.not(id: @season.id).first
    skip "keine zweite Saison im Fixture-Satz" if other_season.nil?

    gamma = Player.create!(lastname: "GAMMA", firstname: "Gerd", fl_name: "G. Gamma", dbu_nr: "333333")
    SeasonParticipation.create!(player: gamma, club: @club, season: other_season)

    rows = RegionServer::PlayerRegistration.selectable_players(tournament: @tournament, club_id: @club.id)

    refute_includes rows.map { |r| r[:id] }, gamma.id,
      "Spieler einer anderen Saison darf nicht angeboten werden"
  end

  # --- register_by_dbu --------------------------------------------------------

  test "register_by_dbu meldet einen Spieler mit state registered" do
    result = register("111111")

    assert_equal 1, result.added.size
    assert_equal @alpha, result.added.first[:player]
    assert_equal 1, result.added.first[:position]

    seeding = @tournament.seedings.find_by(player_id: @alpha.id)
    assert_not_nil seeding
    assert_equal "registered", seeding.state,
      "eine Meldung ist registered — nicht seeded (das waere Teilnehmerlisten-Semantik)"
  end

  test "register_by_dbu vergibt fortlaufende Positionen innerhalb einer Mehrfach-Eingabe" do
    result = register("111111, 222222")

    assert_equal 2, result.added.size
    assert_equal [1, 2], result.added.map { |e| e[:position] }
  end

  test "register_by_dbu meldet Dubletten getrennt zurueck und legt nichts an" do
    @tournament.seedings.create!(player_id: @alpha.id, position: 7)

    assert_no_difference -> { @tournament.seedings.count } do
      result = register("111111")

      assert_empty result.added
      assert_equal 1, result.already_exists.size
      assert_equal 7, result.already_exists.first[:position]
    end
  end

  test "register_by_dbu sammelt unaufloesbare Nummern" do
    result = register("111111, 999999")

    assert_equal 1, result.added.size
    assert_equal ["999999"], result.not_found
  end

  test "register_by_dbu bei leerer Eingabe ist ein no-op" do
    assert_no_difference -> { @tournament.seedings.count } do
      result = register("")

      assert_empty result.added
      assert_empty result.already_exists
      assert_empty result.not_found
    end
  end

  test "register_by_dbu ignoriert Leerraum und leere Segmente" do
    result = register(" 111111 ,, 222222 ,")

    assert_equal 2, result.added.size
    assert_empty result.not_found
  end

  # --- withdraw ---------------------------------------------------------------

  test "withdraw entfernt eine lokale Meldung" do
    seeding = @tournament.seedings.create!(player_id: @alpha.id, position: 1)

    assert_difference -> { @tournament.seedings.count }, -1 do
      assert_equal @alpha, RegionServer::PlayerRegistration.withdraw(tournament: @tournament, seeding_id: seeding.id)
    end
  end

  test "withdraw ruehrt globale Seedings nicht an" do
    global = @tournament.seedings.create!(player_id: @alpha.id, position: 1)
    global.update_column(:id, 4_711) # < MIN_ID = Hoheit der Authority

    assert_no_difference -> { @tournament.seedings.count } do
      assert_nil RegionServer::PlayerRegistration.withdraw(tournament: @tournament, seeding_id: 4_711)
    end
  end

  test "withdraw auf eine fremde seeding_id ist ein no-op" do
    assert_nil RegionServer::PlayerRegistration.withdraw(tournament: @tournament, seeding_id: 999_999_999)
  end

  private

  def register(input)
    RegionServer::PlayerRegistration.register_by_dbu(
      tournament: @tournament, dbu_input: input, acting_user: nil
    )
  end
end
