# frozen_string_literal: true

module ExternalTournament
  # Plan 19-01 (v0.6 F1): Disziplin-Ranking-Setzliste fuer die externe Turnier-App.
  # Liefert die nach PlayerRanking sortierten Spieler einer Disziplin (bestes Ranking =
  # Setzplatz 1) — Quelle fuer die Doppel-KO-Setzliste der App. Read-only, region-scoped,
  # keine Seiteneffekte. Referenz-Impl aus HANDOFF-to-carambus-rankings.md.
  #
  # Disziplin-Aufloesung: exakter name, sonst Synonym-Treffer (Discipline#synonyms ist
  # newline-separiert + enthaelt den Namen selbst).
  #
  # Saison (D-19-01-SEASON, User-Direktive): Rankings/Setzlisten nutzen IMMER die VORSAISON
  # (die Saison vor Season.current_season) — die Rankings der laufenden Saison sind noch nicht
  # final. Vorsaison aus dem current_season-Namen "YYYY/YYYY+1" -> "YYYY-1/YYYY".
  # (Korrigiert die Handoff-Ref-Impl, die die "juengste Saison mit Rankings" nahm.)
  # Vgl. feedback_championship_rankings_prev_season. Explizites season_name uebersteuert.
  class RankingQuery
    Result = Struct.new(:season, :discipline, :ranked, :unranked, keyword_init: true)

    NO_RANK = (1 << 30)
    private_constant :NO_RANK

    def self.find_disciplines(name)
      return [] if name.blank?
      target = name.to_s.strip
      exact = Discipline.where(name: target).to_a
      return exact if exact.any?
      Discipline.where("synonyms ILIKE ?", "%#{target}%").select do |d|
        d.synonyms.to_s.split("\n").map(&:strip).include?(target)
      end
    end

    # season_name explizit -> diese Saison; sonst die VORSAISON (Default, D-19-01-SEASON);
    # defensiver Fallback auf current_season, falls die Vorsaison nicht ermittelbar ist.
    def self.resolve_season(season_name: nil)
      return Season.find_by(name: season_name) if season_name.present?
      previous_season || Season.current_season
    end

    # Vorsaison aus dem current_season-Namen ("YYYY/YYYY+1" -> "YYYY-1/YYYY").
    def self.previous_season
      current = Season.current_season
      start_year = current&.name.to_s.split("/").first.to_i
      return nil if start_year.zero?
      Season.find_by(name: "#{start_year - 1}/#{start_year}")
    end

    # @return [Result, nil] nil wenn die Disziplin nicht aufloesbar ist (Controller -> 404).
    def self.players(region:, discipline_name:, player_cc_ids: [], season_name: nil)
      disciplines = find_disciplines(discipline_name)
      return nil if disciplines.empty?
      discipline_ids = disciplines.map(&:id)
      season = resolve_season(season_name: season_name)

      scope = PlayerRanking.where(region_id: region.id, discipline_id: discipline_ids).includes(:player)
      scope = scope.where(season_id: season.id) if season

      cc_filter = Array(player_cc_ids).map(&:to_s).reject(&:blank?)
      by_cc = {}
      scope.each do |r|
        p = r.player
        next if p.nil?
        next if cc_filter.any? && !cc_filter.include?(p.cc_id.to_s)
        existing = by_cc[p.cc_id]
        by_cc[p.cc_id] = r if existing.nil? || (r.rank || NO_RANK) < (existing.rank || NO_RANK)
      end

      ranked = by_cc.values.sort_by { |r| [r.rank || NO_RANK, -(r.gd || -1e9)] }.map { |r| serialize(r) }
      ranked_cc = ranked.map { |h| h[:cc_id].to_s }
      Result.new(season: season, discipline: disciplines.first,
        ranked: ranked, unranked: cc_filter.reject { |cc| ranked_cc.include?(cc) })
    end

    def self.serialize(ranking)
      p = ranking.player
      {cc_id: p.cc_id, firstname: p.firstname, lastname: p.lastname, dbu_nr: p.dbu_nr&.to_s,
       rank: ranking.rank, gd: ranking.gd, hs: ranking.hs, balls: ranking.balls, innings: ranking.innings}
    end
  end
end
