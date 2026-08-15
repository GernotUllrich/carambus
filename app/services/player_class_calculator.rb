# frozen_string_literal: true

# Plan 21-01 T2 (v0.6 Phase 21): Berechnet `PlayerRanking.player_class_id` aus dem
# maximalen Best-Tournament-GD (`btg`) der zwei abgeschlossenen Vorsaisons je
# Spieler/Disziplin/Region und persistiert das Ergebnis. Quelle der Klassifikation
# ist STO-BTK §1.4 (Stand 06/2019) — speziell §1.4.4 (Klasse aus Jahresabschluss-
# rangliste der Vorsaison, die die zwei Vorjahre umfasst).
#
# Decisions (Plan 21-01):
#   D-21-01-A Saisonfenster = die 2 abgeschlossenen Vorsaisons (current-1, current-2).
#   D-21-01-B Quelle = PlayerRanking.btg; falls in der Ziel-Region/Disziplin alle
#     btg-Werte <= BTG_BACKFILL_THRESHOLD (Heuristik fuer unbefuellt), Backfill aus
#     `max(GameParticipation.gd)` pro Spieler/Saison.
#   D-21-01-C Pool/Snooker → player_class_id bleibt nil (keine STO-Eintraege).
#   D-21-01-E Echtzeit-Hochspielen + Kipp-Spieler (STO §1.4 implizit) NICHT
#     abgebildet — Klasse ist Saison-Snapshot, kein Per-Turnier-Update.
#   D-21-01-F Persistenz auf der juengeren Vorsaison (= Saison, deren
#     Jahresabschlussrangliste die Klasse fuer die NACHFOLGENDE Saison definiert).
#
# Usage:
#   PlayerClassCalculator.call(region: Region.find_by(shortname: "NBV"))   # alle Karambol-Disziplinen
#   PlayerClassCalculator.call(region: ..., discipline: ...)               # nur eine Disziplin
#   PlayerClassCalculator.call(dry_run: true)                              # nichts persistieren, nur zaehlen
#   PlayerClassCalculator.call                                             # alle Regionen + alle Karambol-Disziplinen
class PlayerClassCalculator < ApplicationService
  # Heuristik: wenn max(btg) <= dieser Schwelle, gilt btg in dieser Region/Disziplin
  # als nicht zuverlaessig befuellt → Backfill aus GameParticipation greift.
  BTG_BACKFILL_THRESHOLD = 1.0

  attr_reader :region, :discipline, :dry_run, :stats

  def initialize(kwargs = {})
    @region = kwargs[:region]
    @discipline = kwargs[:discipline]
    @dry_run = kwargs.fetch(:dry_run, false)
    @stats = {
      regions: 0, disciplines: 0, players: 0,
      persisted: 0, skipped: 0, backfilled_pairs: 0
    }
  end

  def call
    seasons = previous_two_seasons
    return stats if seasons.empty?

    regions = region ? [region] : Region.all.to_a
    target_disciplines = (discipline ? [discipline] : disciplines_with_limits).to_a
      .select { |d| Discipline::DISCIPLINE_CLASS_LIMITS.key?(d.name) }

    regions.each do |r|
      stats[:regions] += 1
      target_disciplines.each do |d|
        stats[:disciplines] += 1
        process(r, d, seasons)
      end
    end
    stats
  end

  private

  # D-21-01-A: die zwei abgeschlossenen Vorsaisons (current-1, current-2).
  # Sortierung ueber Season#name (Format "YYYY/YYYY+1") statt id, weil
  # season.id konventionsabhaengig (DBU-id) und nicht zwingend chronologisch
  # ist. String-Sortierung von "YYYY/YYYY+1" ist lexicographisch chronologisch.
  # Returns: Array, aelteste zuerst (seasons.last = juengere Vorsaison).
  def previous_two_seasons
    current = Season.current_season
    return [] unless current
    # with_valid_name haertet zusaetzlich gegen Platzhalter-/Fremd-Saisons ("Unknown Season").
    Season.with_valid_name.where("name < ?", current.name).order(name: :desc).limit(2).to_a.reverse
  end

  def disciplines_with_limits
    Discipline.where(name: Discipline::DISCIPLINE_CLASS_LIMITS.keys)
  end

  def process(region, discipline, seasons)
    rankings = PlayerRanking.where(
      region_id: region.id,
      discipline_id: discipline.id,
      season_id: seasons.map(&:id)
    )
    return if rankings.empty?

    by_player = rankings.group_by(&:player_id)

    # Probe: ist btg zuverlaessig befuellt?
    btg_max = rankings.maximum(:btg).to_f
    use_backfill = btg_max <= BTG_BACKFILL_THRESHOLD
    backfill_gd = use_backfill ? backfill_btg(region, discipline, seasons, by_player.keys) : {}
    stats[:backfilled_pairs] += backfill_gd.size if use_backfill

    pc_cache = {}
    by_player.each do |player_id, player_rankings|
      stats[:players] += 1

      # Pro Saison: Backfill-Wert wenn verfuegbar, sonst Fallback auf btg.
      # Damit funktioniert die Heuristik robust: greift sie unnoetig (Backfill
      # leer), faellt das System auf die btg-Spalte zurueck (z.B. B5 Dreiband
      # gross mit echten btg-Werten ohne GameParticipation).
      values = player_rankings.map do |pr|
        backfill_gd[[player_id, pr.season_id]] || pr.btg.to_f
      end
      max_value = values.compact.max
      # Skip wenn nichts Klassifizierbares da ist:
      #  - nil/negativ: Daten-Quirk
      #  - 0: weder btg noch Backfill lieferte einen positiven Wert (Spieler hat
      #    effektiv kein dokumentiertes Ergebnis in den Vorsaisons → unklassifiziert).
      if max_value.nil? || max_value <= 0
        stats[:skipped] += 1
        next
      end

      shortname = discipline.class_from_val(max_value)
      shortname = adjust_for_min_balls(discipline, shortname, player_rankings)
      if shortname.blank?
        stats[:skipped] += 1
        next
      end

      pc = pc_cache[shortname] ||= ensure_player_class(discipline, shortname)
      if pc.nil?
        # dry_run + Klasse noch nicht in DB → nicht persistieren, aber zaehlen
        stats[:persisted] += 1
        next
      end

      # D-21-01-F: Persistenz bevorzugt auf der juengeren Vorsaison (seasons.last).
      # Fallback auf das einzige verfuegbare Ranking, falls der Spieler nur in der
      # aelteren Vorsaison gerankt war.
      youngest_id = seasons.last.id
      target_pr = player_rankings.find { |pr| pr.season_id == youngest_id } || player_rankings.first
      if !dry_run && target_pr.player_class_id != pc.id
        target_pr.update_columns(player_class_id: pc.id) # rubocop:disable Rails/SkipsModelValidations
      end
      stats[:persisted] += 1
    end
  end

  # D-21-01-B Backfill: max(GameParticipation.gd) pro [player_id, season_id] aus
  # Region-Turnieren in dieser Disziplin. Returns: { [player_id, season_id] => max_gd }.
  def backfill_btg(region, discipline, seasons, player_ids)
    return {} if player_ids.empty?
    GameParticipation
      .joins(game: :tournament)
      .where(player_id: player_ids)
      .where(tournaments: {
        discipline_id: discipline.id,
        season_id: seasons.map(&:id),
        organizer_type: "Region",
        organizer_id: region.id
      })
      .where.not(gd: nil)
      .group("game_participations.player_id", "tournaments.season_id")
      .maximum(:gd)
  end

  # STO-BTK §1.4.3: Dreiband grosses Billard Klasse I braucht zusaetzlich
  # Mindestballzahl 65, Klasse II 45. Bei Verletzung wird die Klasse um eine
  # Stufe degradiert (D-21-01-E Vereinfachung: max(balls) ueber die 2 Saisons,
  # nicht STO-genaues "Saison-spezifisch").
  def adjust_for_min_balls(discipline, shortname, player_rankings)
    return shortname if shortname.blank?
    limits = Discipline::DISCIPLINE_CLASS_LIMITS[discipline.name]
    return shortname unless limits
    rule = limits[shortname]
    return shortname unless rule.is_a?(Array) && rule.length == 2

    _gd_min, balls_min = rule
    max_balls = player_rankings.map { |pr| pr.balls.to_i }.max
    return shortname if max_balls && max_balls >= balls_min

    # Klasse degradieren: in der LIMITS-Reihenfolge (hoch → niedrig) eine Stufe.
    keys = limits.keys
    idx = keys.index(shortname)
    return shortname if idx.nil? || idx == keys.length - 1
    next_short = keys[idx + 1]
    adjust_for_min_balls(discipline, next_short, player_rankings)
  end

  def ensure_player_class(discipline, shortname)
    if dry_run
      PlayerClass.find_by(discipline: discipline, shortname: shortname)
    else
      PlayerClass.find_or_create_by!(discipline: discipline, shortname: shortname)
    end
  end
end
