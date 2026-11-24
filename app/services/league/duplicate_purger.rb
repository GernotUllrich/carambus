# frozen_string_literal: true

# Löscht je Dubletten-Paar des League::SeriesUnifier (zwei Ligen, die in derselben Saison gleich
# hießen) die schwächere Anlage. Hauptfall: BA-Anlage 2022 + CC-Backfill 2025-06 für 2021/22 mit
# denselben Partien (Teams heißen bei CC „… 1“) — die Einzelspiele der Saison zählen doppelt.
#
# Gewinner: mehr PartyGames (wie viel der Saison da ist — BVS 21/22 Oberliga Snooker: BA 1 von 8
# Partien, aber alle Spieler aufgelöst); dann mehr mit beiden Spielern; dann die Anlage mit cc_id
# (Spielplan, Scraper-Lookup); dann mehr Partien; dann die kleinere id.
# Gruppen mit mehr als zwei Ligen: nur wenn höchstens ein Verlierer Partien hat, sonst nur gemeldet.
#
# Löschreihenfolge je Verlierer (Party hat KEIN dependent: :destroy auf party_games):
#   PartyGames → Parties (kaskadiert games, party_cc, seedings, user_parties) →
#   LeagueTeams (kaskadiert seedings, league_team_cc) → League (kaskadiert league_cc).
# Jede Löschung erzeugt eine PaperTrail-Version → die Löschung repliziert an alle Server.
# Schreibt nur mit armed: true, broadcast-frei, je Liga in einer Transaktion, ohne acts_as_list-Nachrücken:
# Seeding hat `acts_as_list scope: :tournament`; Team-Seedings (tournament_id NULL) bilden für acts_as_list
# EINE Liste über alle Regionen — jede Löschung schöbe sonst ~82 000 fremde Positionen per update_all
# (ohne Version, also nicht repliziert) und kostete Sekunden.
#
# placeholders: true löscht zusätzlich BA-Platzhalter OHNE Partien und Turniere („Neue Liga“, „Pooll …“,
# Staffel „Neue Staffel“) und lässt sie aus der Paarbildung heraus.
class League::DuplicatePurger
  Pair = Struct.new(:region, :season, :keep, :drop, :stats, :blocker, keyword_init: true)

  attr_reader :pairs, :skipped, :placeholders, :errors

  def initialize(region: nil, armed: false, placeholders: false)
    @region = region
    @armed = armed
    @with_placeholders = placeholders
    @errors = []
  end

  def call
    @placeholders = @with_placeholders ? find_placeholders : []
    @pairs, @skipped = build_pairs
    purge if @armed
    self
  end

  # Anzahl der zu löschenden Records je Typ (Paare ohne Blocker + Platzhalter).
  def totals
    drop_ids = pairs.reject(&:blocker).map { |p| p.drop.id } + placeholders.map(&:id)
    party_ids = Party.where(league_id: drop_ids).pluck(:id)
    team_ids = LeagueTeam.where(league_id: drop_ids).pluck(:id)
    {leagues: drop_ids.size, parties: party_ids.size, party_games: PartyGame.where(party_id: party_ids).count,
     league_teams: team_ids.size,
     seedings: Seeding.where(league_team_id: team_ids).count + Seeding.where(tournament_type: "Party", tournament_id: party_ids).count}
  end

  private

  def build_pairs
    pairs = []
    skipped = []
    placeholder_ids = placeholders.map(&:id).to_set
    League::SeriesUnifier.new(region: @region).call.series.each do |s|
      s.duplicates.group_by { |c| [c.season, League.staffel_key(c.new_staffel, s.region)] }.each_value do |cs|
        leagues = cs.map(&:league).reject { |l| placeholder_ids.include?(l.id) }
        next if leagues.size < 2

        stats = leagues.to_h { |l| [l.id, stats_for(l)] }
        keep, *drops = leagues.sort_by { |l| score(l, stats[l.id]) }.reverse
        # Mehr als zwei: nur, wenn höchstens ein Verlierer Partien hat (BLVN 2021/22 Kreisliga OH:
        # BA + CC + leere Anlage); sonst ist unklar, was zusammengehört.
        next skipped << leagues if drops.count { |l| stats[l.id][:parties].positive? } > 1

        drops.each do |drop|
          pairs << Pair.new(region: s.region, season: cs.first.season, keep: keep, drop: drop, stats: stats, blocker: blocker(drop))
        end
      end
    end
    [pairs.sort_by { |p| [p.region.shortname, p.season, p.keep.id] }, skipped]
  end

  def find_placeholders
    rel = League.where(organizer_type: "Region")
    rel = rel.where(organizer_id: @region.id) if @region
    rel.where("leagues.name = 'Neue Liga' OR leagues.name LIKE 'Pooll %' OR leagues.staffel_text ILIKE 'Neue Staffel'")
      .where.not(id: Party.select(:league_id)).where.not(id: Tournament.where.not(league_id: nil).select(:league_id))
      .includes(:organizer, :season).order(:id).to_a
  end

  def stats_for(league)
    games = PartyGame.joins(:party).where(parties: {league_id: league.id})
    {parties: Party.where(league_id: league.id).count, games: games.count,
     with_players: games.where.not(player_a_id: nil).where.not(player_b_id: nil).count,
     teams: LeagueTeam.where(league_id: league.id).count}
  end

  def score(league, st) = [st[:games], st[:with_players], league.cc_id.present? ? 1 : 0, st[:parties], -league.id]

  # Gründe, den Verlierer NICHT zu löschen.
  def blocker(league)
    return "hat Turniere" if league.tournaments.exists?

    team_ids = LeagueTeam.where(league_id: league.id).select(:id)
    foreign = Party.where.not(league_id: league.id)
      .where(league_team_a_id: team_ids).or(Party.where.not(league_id: league.id).where(league_team_b_id: team_ids))
    "Teams in fremden Partien" if foreign.exists?
  end

  def purge
    Seeding.acts_as_list_no_update do
      placeholders.each { |l| purge_league(l) }
      pairs.reject(&:blocker).each { |pair| purge_league(pair.drop) }
    end
  end

  def purge_league(league)
    ActiveRecord::Base.transaction do
      Party.where(league_id: league.id).find_each do |p|
        PartyGame.skip_cable_ready_updates { PartyGame.where(party_id: p.id).find_each(&:destroy!) }
        Party.skip_cable_ready_updates { p.destroy! }
      end
      LeagueTeam.where(league_id: league.id).find_each { |lt| LeagueTeam.skip_cable_ready_updates { lt.destroy! } }
      League.skip_cable_ready_updates { league.destroy! }
    end
  rescue => e
    @errors << "League[#{league.id}] #{league.read_attribute(:name)} (#{league.season&.name}): #{e.class}: #{e.message}"
  end
end
