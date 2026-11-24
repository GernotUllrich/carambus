# frozen_string_literal: true

require "test_helper"

class League::CcGhostPurgerTest < ActiveSupport::TestCase
  BASE = 50_000_000 + 91_000

  setup do
    @region = regions(:bbl)
    @season = seasons(:previous)
    @start = Date.parse("#{@season.name.split("/")[0]}-10-01")
    @n = 0
  end

  def id = BASE + (@n += 1)

  def league(cc_id)
    League.create!(id: id, name: "Kreisliga", shortname: "GP#{@n}", organizer: @region, season: @season,
      discipline: disciplines(:branch_pool), cc_id: cc_id, source_kind: "club_cloud",
      source_url: "https://cc.example/sb_spielplan.php?p=23--#{@season.name}-#{cc_id}")
  end

  def team(league, cc_id) = LeagueTeam.create!(id: id, name: "T#{cc_id}", league: league, cc_id: cc_id)

  def party(league, a, b, date)
    p = Party.create!(id: id, league: league, league_team_a: a, league_team_b: b, day_seqno: @n, date: date)
    PartyGame.create!(id: id, party: p, seqno: 1)
    p
  end

  def page(cc_id, team_ids) = team_ids.map { |t| "<a href='sb_mannschaftsplan.php?p=23--x-#{cc_id}-0-#{t}'>T</a>" }.join

  def purger(pages, armed: false)
    League::CcGhostPurger.new(region: @region, season: @season, armed: armed, fetcher: ->(url) { pages[url[/-(\d+)\z/, 1].to_i] }).call
  end

  test "Teams außerhalb der CC-Teamliste und ihre Alt-Partien verschwinden, echte bleiben" do
    l = league(112)
    real_a, real_b = team(l, 643), team(l, 644)
    ghost = team(l, 233)
    ghost2 = team(l, 380)
    Seeding.create!(id: id, league_team: ghost, player: players(:jaspers))
    real_party = party(l, real_a, real_b, @start)
    old_party = party(l, ghost, ghost2, Date.new(2012, 4, 22))

    result = purger({112 => page(112, [643, 644])}, armed: true)

    assert_equal [ghost, ghost2].map(&:id).sort, result.findings.first.ghosts.map(&:id).sort
    assert LeagueTeam.exists?(real_a.id)
    assert Party.exists?(real_party.id)
    refute LeagueTeam.exists?(ghost.id)
    refute Party.exists?(old_party.id)
    assert_equal 0, PartyGame.where(party_id: old_party.id).count
    assert_equal 0, Seeding.where(league_team_id: ghost.id).count
  end

  test "Geist mit Partie in der Saison wird nicht gelöscht" do
    l = league(118)
    real = team(l, 600)
    odd = team(l, 85)
    party(l, real, odd, @start)

    result = purger({118 => page(118, [600])})

    assert_equal [odd.id], result.findings.first.blocked.map(&:id)
    assert_empty result.findings.first.ghosts
  end

  OVERVIEW = "<h1>LIGA</h1><a href='sb_mannschaftsplan.php?p=23--x-999-0-5'>T</a>"

  test "Hülle nur bei Byte-Gleichheit mit der Übersicht; echte Seite ohne Team-Links wird übersprungen" do
    hull = league(222)
    party(hull, team(hull, 1), team(hull, 2), Date.new(2013, 5, 1))
    empty_real = league(329)
    unknown_played = league(223)
    party(unknown_played, team(unknown_played, 3), team(unknown_played, 4), @start)
    with_tournament = league(224)
    Tournament.create!(id: id, title: "T", season: @season, organizer: @region, league: with_tournament)

    result = purger({222 => OVERVIEW, 223 => OVERVIEW, 224 => OVERVIEW, 329 => "<h1>Ersatzbank</h1>", 999_999 => OVERVIEW}, armed: true)

    refute League.exists?(hull.id)
    assert League.exists?(empty_real.id)
    assert League.exists?(unknown_played.id)
    assert League.exists?(with_tournament.id), "Hülle mit Turnier bleibt"
    by_league = result.findings.index_by(&:league)
    assert_equal "keine Team-Links auf der CC-Seite", by_league[empty_real].skipped
    assert_match(/Partien in der Saison/, by_league[unknown_played].skipped)
  end

  test "Dry-Run löscht nichts, nicht abrufbare Seite wird übersprungen" do
    l = league(112)
    ghost = team(l, 233)

    result = purger({112 => nil})

    assert LeagueTeam.exists?(ghost.id)
    assert_equal "Seite nicht abrufbar", result.findings.first.skipped
  end
end
