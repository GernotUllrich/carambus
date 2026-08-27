# frozen_string_literal: true

module Calendar
  # Sammelt Turniere und Liga-Spieltage einer Region in einem Zeitraum als `Calendar::Entry`.
  #
  # EINE Abfrage fuer beide Ansichten (Agenda und Monatsraster): sie unterscheiden sich in der
  # Darstellung, nicht im Inhalt — sonst zeigen sie frueher oder spaeter Verschiedenes.
  #
  # Region, Sparte und Saison kommen aus dem globalen Scope-Band (Scopable) und werden hier
  # nur noch angewandt. `branch` ist ein `Branch`-Record (oder nil = alle Sparten).
  class Query
    DBU_SHORTNAME = "DBU"

    # Wahl "ohne Zuordnung" im Gruppen-Selektor (spiegelt CalendarsController::GROUP_NONE).
    GROUP_NONE = "none"

    def initialize(region:, from:, to:, branch: nil, include_dbu: true,
      kind: nil, group: nil, discipline_name: nil)
      @region = region
      @from = from.to_date
      @to = to.to_date
      @branch_name = branch&.name.presence
      @include_dbu = include_dbu
      @kind = kind.presence
      @group = group.presence
      @discipline_name = discipline_name.presence
    end

    def call
      @call ||= (tournament_entries + party_entries)
        .sort_by { |e| [e.starts_on, e.time.to_s, e.title.to_s] }
    end

    # --- Optionen der beiden Selektoren ------------------------------------------------------
    #
    # Beide speisen sich aus dem, was der Zeitraum im aktuellen Ausschnitt HERGIBT. Ein Selektor
    # ueber alle Records waere ausserhalb des NBV leer (siehe Kommentar im Controller).
    #
    # ⚠️ Die Optionen ignorieren bewusst den JEWEILS EIGENEN Filter — sonst bliebe nach der ersten
    # Wahl genau ein Eintrag stehen und man kaeme nicht mehr heraus.

    # Namen der Turniergruppen (`CategoryCc`) im Zeitraum, plus GROUP_NONE, wenn Turniere OHNE
    # Zuordnung vorkommen.
    #
    # Der Weg ist `Tournament → tournament_cc → category_cc` als **LEFT JOIN**. Ein INNER JOIN
    # wuerde die CC-losen Turniere schon aus der Zaehlung werfen — gemessen am 2026-08-27 haben
    # ueber alle Saisons Zehntausende keinen Zwilling (BVNR 3237, BBV 2469, BVBW 1298 …), in
    # 26/27 auch die beiden CC-losen TBV-Landesmeisterschaften (#18613, #18614).
    def group_options
      @group_options ||= begin
        rows = tournaments_filtered(ignore_group: true)
          .map { |t| t.tournament_cc&.category_cc&.name }
        namen = rows.compact.uniq.sort
        namen << GROUP_NONE if rows.any?(&:nil?)
        namen
      end
    end

    # Disziplin-Namen im Zeitraum — ueber BEIDE Arten, denn `Tournament` und `League` fuehren je
    # eine Disziplin. Branch-abhaengig ist die Liste automatisch, weil die Sparte schon aus dem
    # Band kommt; ein zweiter Branch-Abgleich waere hier doppelt.
    def discipline_options
      @discipline_options ||= begin
        aus_turnieren = tournaments_filtered(ignore_discipline: true)
          .filter_map { |t| t.discipline&.name }
        aus_ligen = leagues_in_scope(ignore_discipline: true)
          .filter_map { |l| l.discipline&.name }
        (aus_turnieren + aus_ligen).uniq.sort
      end
    end

    private

    attr_reader :region, :from, :to, :branch_name, :include_dbu, :kind, :group, :discipline_name

    def regions
      @regions ||= [region, (Region.find_by(shortname: DBU_SHORTNAME) if include_dbu)].compact.uniq
    end

    def source_for(record_region_id)
      (record_region_id == region.id) ? :region : :dbu
    end

    def tournaments? = kind != "team"

    def parties? = kind != "single"

    # --- Turniere -------------------------------------------------------------------------

    # Der SQL-seitige Teil (Region, Zeitraum, Gruppe, Disziplin). Die Sparte bleibt bewusst
    # ausserhalb: sie braucht den Fallback ueber die Disziplin-Wurzel und ist deshalb Ruby-seitig.
    def tournaments_in_scope(ignore_group: false, ignore_discipline: false)
      scope = Tournament.where(region_id: regions.map(&:id))
        .where(date: from.beginning_of_day..to.end_of_day)

      unless ignore_group || group.blank?
        scope = scope.left_joins(tournament_cc: :category_cc)
        scope = if group == GROUP_NONE
          scope.where(category_ccs: {id: nil})
        else
          scope.where(category_ccs: {name: group})
        end
      end

      unless ignore_discipline || discipline_name.blank?
        scope = scope.joins(:discipline).where(disciplines: {name: discipline_name})
      end

      scope
    end

    # Turniere des Zeitraums NACH dem Sparten-Fallback. Der Sparten-Abgleich laeuft Ruby-seitig
    # (er braucht die Disziplin-Wurzel, siehe `branch_of_tournament`) — deshalb muessen auch die
    # Selektor-Optionen durch DIESE Einheit, sonst boete der Disziplin-Selektor bei Sparte
    # "Karambol" munter Pool-Disziplinen an.
    def tournaments_filtered(ignore_group: false, ignore_discipline: false)
      scope = tournaments_in_scope(ignore_group: ignore_group, ignore_discipline: ignore_discipline)
        .includes(:discipline, :location, tournament_cc: :category_cc)
      return scope.to_a unless branch_name

      scope.select { |t| matches_branch?(branch_of_tournament(t)) }
    end

    def tournament_entries
      return [] unless tournaments?

      tournaments_filtered.map do |t|
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

    def leagues_in_scope(ignore_discipline: false)
      scope = League.where(region_id: regions.map(&:id)).includes(:discipline)
      unless ignore_discipline || discipline_name.blank?
        scope = scope.joins(:discipline).where(disciplines: {name: discipline_name})
      end
      scope = scope.select { |l| matches_branch?(branch_of_league(l)) } if branch_name
      scope
    end

    def party_entries
      # Eine gewaehlte Gruppe ist eine reine Turnier-Achse — Spieltage tragen keine Kategorie.
      # Der Controller setzt `kind` dann sichtbar auf "single"; hier reicht der Kind-Schalter.
      return [] unless parties?

      leagues = Array(leagues_in_scope)
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
