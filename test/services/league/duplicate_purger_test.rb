# frozen_string_literal: true

require "test_helper"

class League::DuplicatePurgerTest < ActiveSupport::TestCase
  BASE = 50_000_000 + 89_000

  setup do
    @region = regions(:bbl)
    @pool = disciplines(:branch_pool)
    @n = 0
  end

  def league(name, season, **attrs)
    @n += 1
    League.create!(id: BASE + @n, name: name, shortname: "DP#{@n}", organizer: @region,
      season: seasons(season), discipline: @pool, **attrs)
  end

  # Liga mit zwei Teams, einer Partie und `games` Einzelspielen, davon `resolved` mit beiden Spielern.
  def fill(league, games:, resolved:)
    @n += 1
    a = LeagueTeam.create!(id: BASE + 100 + @n, name: "A#{@n}", league: league)
    b = LeagueTeam.create!(id: BASE + 200 + @n, name: "B#{@n}", league: league)
    Seeding.create!(id: BASE + 300 + @n, league_team: a, player: players(:jaspers))
    party = Party.create!(id: BASE + 400 + @n, league: league, league_team_a: a, league_team_b: b, day_seqno: 1)
    games.times do |i|
      pl = (i < resolved) ? players(:jaspers) : nil
      PartyGame.create!(id: BASE + 500 + @n * 20 + i, party: party, seqno: i + 1, player_a: pl, player_b: pl)
    end
    party
  end

  def purge(armed: true) = League::DuplicatePurger.new(region: @region, armed: armed).call

  test "vollständigere Anlage bleibt, die andere verschwindet ohne Waisen" do
    ba = league("Pool Oberliga", :previous, source_kind: "ba")
    cc = league("Oberliga", :previous, cc_id: 3, source_kind: "club_cloud")
    league("Oberliga - Pool", :current)
    fill(ba, games: 4, resolved: 4)
    cc_party = fill(cc, games: 4, resolved: 1)
    cc_team_ids = cc.league_teams.pluck(:id)

    result = purge

    assert_equal [[ba, cc]], result.pairs.map { |p| [p.keep, p.drop] }
    assert League.exists?(ba.id)
    refute League.exists?(cc.id)
    refute Party.exists?(cc_party.id)
    assert_equal 0, PartyGame.where(party_id: cc_party.id).count
    assert_equal 0, LeagueTeam.where(id: cc_team_ids).count
    assert_equal 0, Seeding.where(league_team_id: cc_team_ids).count
    assert_equal 4, PartyGame.joins(:party).where(parties: {league_id: ba.id}).count
  end

  test "fremde Team-Seedings rücken nicht nach" do
    ba = league("Pool Oberliga", :previous)
    cc = league("Oberliga", :previous, cc_id: 3)
    league("Oberliga - Pool", :current)
    fill(ba, games: 1, resolved: 0)
    fill(cc, games: 2, resolved: 0)
    other = league("Bezirksliga", :previous)
    foreign = Seeding.create!(id: BASE + 999, player: players(:cho),
      league_team: LeagueTeam.create!(id: BASE + 998, name: "X", league: other))
    position = foreign.reload.position

    purge

    refute League.exists?(ba.id)
    assert_equal position, foreign.reload.position
  end

  test "mehr Einzelspiele schlägt mehr aufgelöste Spieler" do
    ba = league("Oberliga Snooker", :previous)
    cc = league("Oberliga - Snooker", :previous, cc_id: 17)
    league("Oberliga Snooker", :current)
    fill(ba, games: 3, resolved: 3)
    fill(cc, games: 8, resolved: 2)

    assert_equal [[cc, ba]], purge(armed: false).pairs.map { |p| [p.keep, p.drop] }
  end

  test "Dreiergruppe: nur wenn höchstens ein Verlierer Partien hat" do
    ba = league("Pool Oberliga", :previous)
    cc = league("Oberliga", :previous, cc_id: 3)
    empty = league("Oberliga - Pool", :previous)
    league("Oberliga - Pool", :current)
    fill(ba, games: 2, resolved: 2)
    fill(cc, games: 3, resolved: 0)

    assert_equal [[cc, ba], [cc, empty]].map { |k, d| [k.id, d.id] }.sort,
      purge(armed: false).pairs.map { |p| [p.keep.id, p.drop.id] }.sort

    fill(empty, games: 1, resolved: 0)
    result = purge(armed: false)
    assert_empty result.pairs
    assert_equal 1, result.skipped.size
  end

  test "Platzhalter ohne Partien werden gelöscht, mit Partien bleiben sie" do
    empty = league("Neue Liga", :previous)
    typo = league("Pooll Landesliga OH", :previous)
    shell = league("Oberliga", :season_2024, staffel_text: "Neue Staffel")
    played = league("Neue Liga", :current)
    fill(played, games: 1, resolved: 0)

    result = League::DuplicatePurger.new(region: @region, armed: true, placeholders: true).call

    assert_equal [empty, typo, shell].map(&:id).sort, result.placeholders.map(&:id).sort
    refute League.exists?(empty.id)
    refute League.exists?(shell.id)
    assert League.exists?(played.id)
    assert League::DuplicatePurger.new(region: @region).call.placeholders.empty?, "ohne Schalter keine Platzhalter"
  end

  test "Gleichstand: die Anlage mit cc_id bleibt; Dry-Run löscht nichts" do
    ba = league("Pool Oberliga", :previous)
    cc = league("Oberliga", :previous, cc_id: 3)
    league("Oberliga - Pool", :current)

    result = purge(armed: false)

    assert_equal [[cc, ba]], result.pairs.map { |p| [p.keep, p.drop] }
    assert League.exists?(ba.id)
    assert_equal 1, result.totals[:leagues]
  end

  test "Verlierer mit Turnier wird nicht gelöscht" do
    ba = league("Pool Oberliga", :previous)
    league("Oberliga", :previous, cc_id: 3)
    league("Oberliga - Pool", :current)
    Tournament.create!(id: BASE + 900, title: "T", season: seasons(:previous), organizer: @region, league: ba)

    result = purge

    assert_equal "hat Turniere", result.pairs.first.blocker
    assert League.exists?(ba.id)
  end
end
