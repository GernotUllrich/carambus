# frozen_string_literal: true

require "test_helper"

class League::OrphanTeamPurgerTest < ActiveSupport::TestCase
  BASE = 50_000_000 + 93_000
  GONE = BASE + 999 # Liga-ID, die es nicht gibt

  setup do
    @n = 0
    @league = League.create!(id: id, name: "Kreisliga", shortname: "OT", organizer: regions(:bbl),
      season: seasons(:previous), discipline: disciplines(:branch_pool))
  end

  def id = BASE + (@n += 1)

  def orphan
    t = LeagueTeam.create!(id: id, name: "T#{@n}", league: @league)
    t.update_column(:league_id, GONE)
    t
  end

  test "löscht nur freie Teams ohne Liga; jeder Verweis blockiert; Liga-Teams bleiben" do
    free = orphan
    with_seeding = orphan
    Seeding.create!(id: id, league_team: with_seeding, player: players(:jaspers))
    as_a, as_host, as_no_show = orphan, orphan, orphan
    other = LeagueTeam.create!(id: id, name: "B", league: @league)
    Party.create!(id: id, league: @league, league_team_a: as_a, league_team_b: other, day_seqno: 1)
    Party.create!(id: id, league: @league, league_team_a: other, league_team_b: other, day_seqno: 2, host_league_team_id: as_host.id)
    Party.create!(id: id, league: @league, league_team_a: other, league_team_b: other, day_seqno: 3, no_show_team_id: as_no_show.id)
    with_cc = orphan
    LeagueTeamCc.new(id: id, league_team: with_cc, name: "X").save!(validate: false)

    result = League::OrphanTeamPurger.new(armed: true).call

    assert_equal [free.id], result.orphans
    assert_equal [with_seeding, as_a, as_host, as_no_show, with_cc].map(&:id).sort, result.blocked
    assert_equal 1, result.deleted
    assert_empty result.errors
    refute LeagueTeam.exists?(free.id)
    assert LeagueTeam.exists?(other.id)
  end

  test "Dry-Run löscht nichts; zweiter ARMED-Lauf findet nichts mehr" do
    t = orphan

    assert_equal [t.id], League::OrphanTeamPurger.new.call.orphans
    assert LeagueTeam.exists?(t.id)

    League::OrphanTeamPurger.new(armed: true).call
    assert_empty League::OrphanTeamPurger.new(armed: true).call.orphans
  end
end
