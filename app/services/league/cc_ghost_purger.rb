# frozen_string_literal: true

# Räumt CC-Rollover-Reste einer Region und Saison ab. Die CC lieferte beim ersten Scrape einer neuen
# Saison (BVS/NBV Juli 2025) noch die Teams und teils die Partien der Vorjahre; der Partie-Purge vom
# Juli 2026 erfasste nur `sb_spielbericht`-Quellen und keine Teams. Zurück blieben Teams ohne Partie
# (mit Kader-Seedings), kopierte Partien mit Alt-Datum und Ligen, die die CC gar nicht kennt.
#
# Diskriminator ist die LIVE-Teamliste der CC-Spielplanseite (`sb_mannschaftsplan.php?p=…-<liga>-0-<team>`),
# nicht eine ID-Schwelle und nicht „hat nicht gespielt“ (laufende Saison: Teams ohne Partie sind normal).
# - Geist = Team der Liga, dessen cc_id nicht in der CC-Teamliste steht. Gelöscht nur, wenn ALLE seine
#   Partien in dieser Liga liegen und kein Datum in der Saison haben (sonst Blocker, Team bleibt).
# - Hülle = Liga, deren Seite byte-identisch mit der Seite einer sicher unbekannten ID ist (die CC liefert
#   dafür eine feste Übersicht) UND die keine Partie mit Datum in der Saison hat. Wird ganz gelöscht.
# Übersprungen: nicht abrufbare Seiten und echte Seiten ohne eigene Team-Links.
#
# Löschreihenfolge wie im DuplicatePurger: PartyGames → Parties → LeagueTeams (Seedings kaskadieren) →
# ggf. League; broadcast-frei, ohne acts_as_list-Nachrücken, je Liga eine Transaktion, PaperTrail → Sync.
class League::CcGhostPurger
  Finding = Struct.new(:league, :cc_team_ids, :ghosts, :ghost_parties, :blocked, :hull, :skipped, keyword_init: true)

  attr_reader :findings, :errors

  def initialize(region:, season:, armed: false, fetcher: ->(url) { League.cc_http_get(url) })
    @region = region
    @season = season
    @armed = armed
    @fetcher = fetcher
    @errors = []
  end

  def call
    @findings = leagues.map { |l| inspect_league(l) }
    purge if @armed
    self
  end

  def totals
    f = findings.reject(&:skipped)
    team_ids = f.flat_map { |x| x.hull ? LeagueTeam.where(league_id: x.league.id).ids : x.ghosts.map(&:id) }
    party_ids = f.flat_map { |x| x.hull ? Party.where(league_id: x.league.id).ids : x.ghost_parties.map(&:id) }
    {leagues: f.count(&:hull), league_teams: team_ids.size, parties: party_ids.size,
     party_games: PartyGame.where(party_id: party_ids).count, seedings: Seeding.where(league_team_id: team_ids).count}
  end

  private

  def leagues
    League.where(organizer: @region, season: @season, source_kind: "club_cloud").where.not(cc_id: nil)
      .where.not(source_url: [nil, ""]).order(:id).to_a
  end

  def inspect_league(league)
    html = fetch(league.source_url)
    return Finding.new(league: league, skipped: "Seite nicht abrufbar") if html.blank?

    cc_ids = html.scan(/sb_mannschaftsplan\.php\?p=[^'"]*-#{league.cc_id}-0-(\d+)/).flatten.map(&:to_i).to_set
    if html == unknown_page(league.source_url)
      return Finding.new(league: league, cc_team_ids: cc_ids, skipped: "CC kennt die Liga nicht, aber Partien in der Saison") if Party.where(league_id: league.id).any? { |p| in_season?(p) }
      return Finding.new(league: league, cc_team_ids: cc_ids, skipped: "CC kennt die Liga nicht, aber sie hat Turniere") if league.tournaments.exists?

      return Finding.new(league: league, cc_team_ids: cc_ids, hull: true, ghosts: [], ghost_parties: [], blocked: [])
    end
    # Echte Seite ohne eigene Team-Links (z. B. Bundesligen in der NBV-CC): Mitgliedschaft nicht belegbar.
    return Finding.new(league: league, cc_team_ids: cc_ids, skipped: "keine Team-Links auf der CC-Seite") if cc_ids.empty?

    ghosts, blocked, ghost_parties = [], [], []
    LeagueTeam.where(league_id: league.id).find_each do |t|
      next if cc_ids.include?(t.cc_id)

      own = Party.where(league_team_a_id: t.id).or(Party.where(league_team_b_id: t.id)).to_a
      if own.any? { |p| p.league_id != league.id || in_season?(p) }
        blocked << t
      else
        ghosts << t
        ghost_parties |= own
      end
    end
    Finding.new(league: league, cc_team_ids: cc_ids, ghosts: ghosts, ghost_parties: ghost_parties, blocked: blocked, hull: false)
  end

  # Die CC liefert für eine unbekannte Liga-ID eine feste Übersichtsseite. Referenz: dieselbe URL mit
  # der ID 999999, je Domain und Saison einmal geholt. Nur Byte-Gleichheit zählt (2026-11-24 belegt:
  # „keine Team-Links“ allein trifft auch echte Ligen wie NBV Ersatzbank oder BVS Oberliga RLP).
  def unknown_page(url)
    ref = url.sub(/-\d+\z/, "-999999")
    (@unknown_pages ||= {})[ref] ||= fetch(ref) || :unavailable
  end

  def fetch(url)
    @fetcher.call(url)
  rescue => e
    @errors << "Abruf #{url}: #{e.class}: #{e.message}"
    nil
  end

  # TimeWithZone → Date (Season#includes_date prüft auf Date, siehe Memory cc-rollover-copies-date-discriminator).
  def in_season?(party) = party.date.present? && @season.includes_date(party.date.to_date)

  def purge
    Seeding.acts_as_list_no_update do
      findings.reject(&:skipped).each do |f|
        ActiveRecord::Base.transaction do
          parties = f.hull ? Party.where(league_id: f.league.id).to_a : f.ghost_parties
          teams = f.hull ? LeagueTeam.where(league_id: f.league.id).to_a : f.ghosts
          parties.each do |p|
            PartyGame.skip_cable_ready_updates { PartyGame.where(party_id: p.id).find_each(&:destroy!) }
            Party.skip_cable_ready_updates { p.destroy! }
          end
          teams.each { |t| LeagueTeam.skip_cable_ready_updates { t.destroy! } }
          League.skip_cable_ready_updates { f.league.destroy! } if f.hull
        end
      rescue => e
        @errors << "League[#{f.league.id}] #{f.league.read_attribute(:name)}: #{e.class}: #{e.message}"
      end
    end
  end
end
