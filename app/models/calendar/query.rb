# frozen_string_literal: true

module Calendar
  # Sammelt Turniere und Liga-Spieltage einer Region in einem Zeitraum als `Calendar::Entry`.
  #
  # EINE Abfrage fuer beide Ansichten (Agenda und Monatsraster): sie unterscheiden sich in der
  # Darstellung, nicht im Inhalt — sonst zeigen sie fruher oder spaeter Verschiedenes.
  class Query
    DBU_SHORTNAME = "DBU"

    def initialize(region:, from:, to:, branch_name: nil, include_dbu: true)
      @region = region
      @from = from.to_date
      @to = to.to_date
      @branch_name = branch_name.presence
      @include_dbu = include_dbu
    end

    def call
      (tournament_entries + party_entries).sort_by { |e| [e.starts_on, e.time.to_s, e.title.to_s] }
    end

    private

    attr_reader :region, :from, :to, :branch_name, :include_dbu

    def regions
      @regions ||= [region, (Region.find_by(shortname: DBU_SHORTNAME) if include_dbu)].compact.uniq
    end

    def source_for(record_region_id)
      (record_region_id == region.id) ? :region : :dbu
    end

    # --- Turniere -------------------------------------------------------------------------

    def tournament_entries
      scope = Tournament.where(region_id: regions.map(&:id))
        .where(date: from.beginning_of_day..to.end_of_day)
        .includes(:discipline, :location)
      scope = scope.select { |t| matches_branch?(branch_of_tournament(t)) } if branch_name

      Array(scope).map do |t|
        Entry.new(
          starts_on: t.date.to_date,
          ends_on: t.end_date&.to_date,
          time: format_time(t.date),
          title: t.title.to_s,
          subtitle: t.discipline&.name,
          branch_name: branch_of_tournament(t),
          location_name: t.location&.name.presence,
          kind: :tournament,
          source: source_for(t.region_id),
          record: t
        )
      end
    end

    # --- Spieltage ------------------------------------------------------------------------

    def party_entries
      leagues = League.where(region_id: regions.map(&:id)).includes(:discipline)
      leagues = leagues.select { |l| matches_branch?(branch_of_league(l)) } if branch_name
      return [] if leagues.empty?

      by_league = leagues.index_by(&:id)
      parties = Party.where(league_id: by_league.keys)
        .where(date: from.beginning_of_day..to.end_of_day)
        .includes(:league_team_a, :league_team_b, :location)

      parties.map do |p|
        league = by_league[p.league_id]
        Entry.new(
          starts_on: p.date.to_date,
          ends_on: nil,
          time: format_time(p.date),
          title: league&.name.to_s,
          subtitle: [p.league_team_a&.name, p.league_team_b&.name].compact.join(" – ").presence,
          branch_name: branch_of_league(league),
          league_name: league&.name.to_s,
          location_name: p.location&.name.presence,
          kind: :party,
          source: source_for(league&.region_id),
          record: p
        )
      end
    end

    # --- Sparte ---------------------------------------------------------------------------

    # ⚠️ `branch_id` ALLEIN reicht nicht: gemessen am 2026-08-27 tragen 43 von 305 Ligen der
    # Saison 2026/2027 keinen Stempel (z.B. BVBW „Bezirksliga Mitte 1"), gehoeren ueber ihre
    # Disziplin aber sehr wohl zu einer Sparte. Ein Filter auf `branch_id` verschluckt sie STILL.
    #
    # Deshalb der Fallback ueber `League#branch` (league.rb) — die Disziplin-Wurzel.
    #
    # `Branch` ist STI auf `disciplines` (`type: "Branch"`, `super_discipline_id: nil`), beide Wege
    # fuehren also in DIESELBE Tabelle und liefern denselben Record — der gestempelte Wert und der
    # ueber die Hierarchie berechnete sind dasselbe, wenn beide da sind. Verglichen wird trotzdem
    # ueber den Namen: `branch_id` KANN fehlen, die Hierarchie traegt dann allein.
    #
    # Das Nachstempeln der 43 Ligen ist ein eigener Plan — der Kalender wartet nicht darauf.
    def branch_of_league(league)
      return nil if league.nil?

      Branch.find_by(id: league.branch_id)&.name || begin
        league.branch&.name
      rescue
        nil
      end
    end

    def branch_of_tournament(tournament)
      Branch.find_by(id: tournament.branch_id)&.name ||
        (tournament.discipline && root_discipline_name(tournament.discipline))
    end

    def root_discipline_name(discipline)
      d = discipline
      d = d.super_discipline while d&.super_discipline.present?
      d&.name
    end

    def matches_branch?(name)
      name.present? && name.casecmp?(branch_name)
    end

    def format_time(value)
      return nil if value.blank?

      formatted = value.strftime("%H:%M")
      (formatted == "00:00") ? nil : formatted
    end
  end
end
