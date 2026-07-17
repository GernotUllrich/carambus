# frozen_string_literal: true

require "test_helper"

# Plan 46.5-03: Party.cleanup_phantom_duplicates — entfernt leere Phantom-Dubletten
# (0 party_games + ergebnislos) je natürlichem Schlüssel (league+day_seqno+teams), behält
# IMMER >= 1 je Termin und NIE eine gespielte. Fixiert den „Oberliga - Pool"-Phantom-Befund.
class PartyCleanupTest < ActiveSupport::TestCase
  setup do
    @nbv = regions(:nbv)
    @season = seasons(:current)
    @branch = Branch.create!(name: "PoolPC")
    @league = League.create!(name: "PC Liga", shortname: "PC-L",
      organizer: @nbv, season: @season, discipline: @branch, cc_id: 947_001)
    @a = LeagueTeam.create!(league: @league, name: "PC A")
    @b = LeagueTeam.create!(league: @league, name: "PC B")
  end

  # day_seqno bestimmt die Gruppe (gleiche teams). result "" / ":" + 0 games = Phantom.
  def party(day_seqno, result, with_game: false)
    p = Party.create!(league: @league, league_team_a: @a, league_team_b: @b,
      host_league_team: @a, day_seqno: day_seqno, date: Date.new(2026, 1, 10), data: {"result" => result})
    PartyGame.create!(party: p, seqno: 1, discipline: @branch, data: {"result" => {"Ergebnis" => "7:0"}}) if with_game
    p
  end

  test "AC-1: echte Party (Ziffern-Ergebnis) bleibt, 2 Phantome (':') desselben Termins gelöscht" do
    real = party(1, "5:3")
    party(1, ":")
    party(1, ":")
    assert_equal 3, @league.parties.count

    r = Party.cleanup_phantom_duplicates(scope: @league.parties, dry_run: false)
    assert_equal 2, r[:deleted]
    assert_equal 1, @league.parties.reload.count
    assert Party.exists?(real.id), "gespielte Party muss bleiben"
  end

  test "AC-1b: echte Party über party_games (Ergebnis ':') bleibt; reines Phantom gelöscht" do
    real = party(2, ":", with_game: true) # hat party_games → KEIN Phantom
    party(2, ":")                          # 0 games + ":" → Phantom
    r = Party.cleanup_phantom_duplicates(scope: @league.parties, dry_run: false)
    assert_equal 1, r[:deleted]
    assert Party.exists?(real.id), "Party mit party_games darf nicht gelöscht werden"
  end

  test "AC-2: nur Phantome (3×) → genau EINE (niedrigste id) bleibt" do
    keep = party(3, ":")
    party(3, ":")
    party(3, ":")
    r = Party.cleanup_phantom_duplicates(scope: @league.parties, dry_run: false)
    assert_equal 2, r[:deleted]
    remaining = @league.parties.where("day_seqno = 3").to_a
    assert_equal 1, remaining.size
    assert_equal keep.id, remaining.first.id, "die niedrigste id bleibt (kanonische Fixture)"
  end

  test "AC-3a: idempotent — zweiter Lauf löscht 0" do
    party(4, "5:3")
    party(4, ":")
    Party.cleanup_phantom_duplicates(scope: @league.parties, dry_run: false)
    r2 = Party.cleanup_phantom_duplicates(scope: @league.parties, dry_run: false)
    assert_equal 0, r2[:deleted]
  end

  test "AC-3b: dry_run löscht nichts, nennt aber die Kandidaten" do
    party(5, "5:3")
    party(5, ":")
    before = Party.count
    r = Party.cleanup_phantom_duplicates(scope: @league.parties, dry_run: true)
    assert_equal before, Party.count, "dry_run darf nichts löschen"
    assert_equal 1, r[:deleted], "Report nennt die Kandidaten"
    assert_equal 1, r[:deleted_ids].size
  end

  test "Negativ: verschiedene Termine (je 1 Party) → nichts gelöscht" do
    party(6, ":")
    party(7, ":")
    r = Party.cleanup_phantom_duplicates(scope: @league.parties, dry_run: false)
    assert_equal 0, r[:deleted], "Einzel-Parties verschiedener Termine sind keine Dubletten"
  end
end
