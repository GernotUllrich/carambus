# frozen_string_literal: true

module ExternalTournament
  # Plan 19-01 (Ranking-Setzliste): read-only, region-scoped Sortierung einer
  # Spielerliste nach dem offiziellen PlayerRanking einer Disziplin.
  #
  # Genutzt von der externen App (Doppel-KO u. a.), um aus ausgewaehlten Spielern
  # eine Setzliste zu erzeugen: bestes Ranking = Setzplatz 1.
  #
  #   players(region:, discipline_name:, player_cc_ids:)
  #     -> { season:, discipline:, ranked:[...], unranked:[cc_id,...] }
  #
  # Reine Reads, keine Seiteneffekte.
  #
  # Disziplin-Aufloesung (D-19-01-A): exakter Name, sonst Synonym-Treffer
  # (Discipline#synonyms ist newline-separiert und enthaelt den Namen selbst).
  # Mehrere Disziplinen gleichen Namens (verschiedene table_kinds) werden als
  # Kandidaten-Menge behandelt.
  #
  # Saison (D-19-01-B): per Default die juengste Saison, fuer die ueberhaupt
  # Rankings dieser Disziplin+Region existieren (Rankings hinken der laufenden
  # Saison oft hinterher). Optional per season_name uebersteuerbar.
  class RankingQuery
    Result = Struct.new(:season, :discipline, :ranked, :unranked, keyword_init: true)

    def self.find_disciplines(name)
      return [] if name.blank?
      target = name.to_s.strip
      exact = Discipline.where(name: target).to_a
      return exact if exact.any?
      Discipline.where("synonyms ILIKE ?", "%#{target}%").select do |d|
        d.synonyms.to_s.split("\n").map(&:strip).include?(target)
      end
    end

    # Liefert die zu verwendende Saison (juengste mit Rankings) oder nil.
    def self.resolve_season(region:, discipline_ids:, season_name: nil)
      if season_name.present?
        return Season.find_by(name: season_name)
      end
      sid = PlayerRanking
        .where(region_id: region.id, discipline_id: discipline_ids)
        .order(season_id: :desc)
        .limit(1)
        .pick(:season_id)
      sid ? Season.find_by(id: sid) : Season.current_season
    end

    def self.players(region:, discipline_name:, player_cc_ids: [], season_name: nil)
      disciplines = find_disciplines(discipline_name)
      return nil if disciplines.empty?
      discipline_ids = disciplines.map(&:id)
      season = resolve_season(region: region, discipline_ids: discipline_ids, season_name: season_name)

      scope = PlayerRanking
        .where(region_id: region.id, discipline_id: discipline_ids)
        .includes(:player)
      scope = scope.where(season_id: season.id) if season

      cc_filter = Array(player_cc_ids).map(&:to_s).reject(&:blank?)
      by_cc = {}
      scope.each do |r|
        p = r.player
        next if p.nil?
        next if cc_filter.any? && !cc_filter.include?(p.cc_id.to_s)
        # Pro Spieler nur den besten (kleinsten) Rang behalten, falls mehrere
        # Kandidaten-Disziplinen denselben Spieler liefern.
        existing = by_cc[p.cc_id]
        by_cc[p.cc_id] = r if existing.nil? || (r.rank || 1 << 30) < (existing.rank || 1 << 30)
      end

      ranked = by_cc.values
        .sort_by { |r| [r.rank || (1 << 30), -(r.gd || -1e9)] }
        .map { |r| serialize(r) }

      ranked_cc = ranked.map { |h| h[:cc_id].to_s }
      unranked = cc_filter.reject { |cc| ranked_cc.include?(cc) }

      Result.new(
        season: season,
        discipline: disciplines.first,
        ranked: ranked,
        unranked: unranked
      )
    end

    def self.serialize(r)
      p = r.player
      {
        cc_id: p.cc_id,
        firstname: p.firstname,
        lastname: p.lastname,
        dbu_nr: p.dbu_nr&.to_s,
        rank: r.rank,
        gd: r.gd,
        hs: r.hs,
        balls: r.balls,
        innings: r.innings
      }
    end
  end
end
