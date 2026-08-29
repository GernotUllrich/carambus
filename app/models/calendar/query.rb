# frozen_string_literal: true

module Calendar
  # Sammelt Turniere und Liga-Spieltage einer Region in einem Zeitraum als `Calendar::Entry`.
  #
  # EINE Abfrage fuer beide Ansichten (Agenda und Monatsraster): sie unterscheiden sich in der
  # Darstellung, nicht im Inhalt — sonst zeigen sie frueher oder spaeter Verschiedenes.
  #
  # Region, Sparte und Saison kommen aus dem globalen Scope-Band (Scopable) und werden hier
  # nur noch angewandt. `branch` ist ein `Branch`-Record, eine LISTE davon, oder nil
  # (= alle Sparten). Mehrere sind zugelassen, weil eine Tischart mehrere Sparten traegt:
  # auf dem kleinen Billard und dem Match Billard wird sowohl Karambol als auch Kegel
  # gespielt (5-Pin auch auf dem grossen). Ein Spielort schraenkt deshalb auf eine MENGE ein,
  # nicht auf eine einzelne Sparte.
  class Query
    DBU_SHORTNAME = "DBU"

    # Wahl "ohne Zuordnung" im Gruppen-Selektor (spiegelt CalendarsController::GROUP_NONE):
    # Turniere ohne Meisterschaftstyp, einschliesslich der CC-losen.
    GROUP_NONE = "none"

    # Dasselbe fuer den Ort: gemessen am 2026-08-28 (Saison 25/26) tragen 8 BVNR-Turniere und
    # 15 BVNR-Spieltage keinen Austragungsort, dazu 1 DBU-Spieltag. Ohne eigene Wahl waeren sie
    # ueber den Ortsfilter unerreichbar.
    LOCATION_NONE = "none"

    def initialize(region:, from:, to:, branch: nil, include_dbu: true,
      kind: nil, group: nil, discipline_name: nil, location_name: nil)
      @region = region
      @from = from.to_date
      @to = to.to_date
      # `Array.wrap` statt `Array()`: bei einem einzelnen Record wuerde `Array()` dessen `to_a`
      # suchen, `wrap` fragt nur nach `to_ary` und packt ihn sonst in ein Element.
      @branch_names = Array.wrap(branch).filter_map { |b| b&.name.presence }
      @include_dbu = include_dbu
      @kind = kind.presence
      @group = group.presence
      @discipline_name = discipline_name.presence
      @location_name = location_name.presence
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

    # Namen der Turniergruppen im Zeitraum, plus GROUP_NONE, wenn Turniere ohne Gruppe vorkommen.
    #
    # ⚠️ Quelle ist `tournament_ccs.championship_type_cc_name` — NICHT `CategoryCc`.
    # 42-02 hatte CategoryCc gewaehlt und daraus geschlossen, der Selektor sei "faktisch ein
    # NBV-Feature". Das war eine Folge der Feldwahl, keine Eigenschaft der Daten. Gemessen am
    # 2026-08-27, Saison 26/27:
    #
    #   Region  Turniere  mit championship_type  mit category_cc
    #   NBV           55                     55               49
    #   BVNR         178                    178                0
    #   DBU           71                     71                0
    #   BVB           69                     69                0
    #   BLMR          31                     31                0
    #
    # championship_type ist ueberall zu 100 % gepflegt und traegt reine Turnierserien (NDM,
    # NordCup, Grand Prix, Vorgabepokal, NDJM, Bezirksmeisterschaft), waehrend CategoryCc Serien
    # mit Alters-/Geschlechtsklassen mischt und in Einzelfaellen widerspricht (#18612 trug
    # Kategorie "Grand Prix" bei Kurzname "1NC" und Typ "NordCup (NC)").
    #
    # Gruppiert wird ueber den DENORMALISIERTEN Namen, nicht ueber `championship_type_cc_id`:
    # die Tabelle enthaelt vier gleichnamige "Norddeutsche Meisterschaft"-Records.
    #
    # LEFT JOIN, damit CC-lose Turniere nicht schon aus der Zaehlung fallen — ueber alle Saisons
    # haben Zehntausende keinen Zwilling (BVNR 3237, BBV 2469, BVBW 1298 …), in 26/27 auch die
    # beiden CC-losen TBV-Landesmeisterschaften (#18613, #18614).
    def group_options
      @group_options ||= begin
        rows = tournaments_filtered(ignore_group: true)
          .map { |t| gruppenname(t.tournament_cc&.championship_type_cc_name) }
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
        aus_ligen = leagues_with_parties(ignore_discipline: true)
          .filter_map { |l| l.discipline&.name }
        (aus_turnieren + aus_ligen).uniq.sort
      end
    end

    # Austragungsorte im Zeitraum — ueber BEIDE Arten, plus LOCATION_NONE, wenn Termine ohne Ort
    # vorkommen.
    #
    # ⚠️ Die Liste kann LANG werden. Gemessen am 2026-08-28, Saison 25/26 — verschiedene Orte
    # (Turniere / Spieltage): DBU 25/110, BVNR 34/43, BLMR 21/52, BVB 10/18, NBV 8/20, BLVSA 0/0.
    # Ueber hundert Orte in einer Chip-Reihe waeren unbrauchbar; der Selektor ist deshalb
    # eingeklappt und zeigt nur den gewaehlten Wert. Bei BLVSA faellt er ganz weg (< 2 Optionen).
    def location_options
      @location_options ||= begin
        turniere = tournaments_filtered(ignore_location: true)
        liga_ids = Array(leagues_in_scope).map(&:id)
        spieltage = liga_ids.empty? ? [] : parties_in_scope(liga_ids, ignore_location: true).includes(:location)

        namen = (turniere.map { |t| t.location&.name.presence } +
                 spieltage.map { |p| p.location&.name.presence })
        liste = namen.compact.uniq.sort
        liste << LOCATION_NONE if namen.any?(&:nil?)
        liste
      end
    end

    private

    attr_reader :region, :from, :to, :branch_names, :include_dbu, :kind, :group, :discipline_name,
      :location_name

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
    def tournaments_in_scope(ignore_group: false, ignore_discipline: false, ignore_location: false)
      scope = Tournament.where(region_id: regions.map(&:id))
        .where(date: from.beginning_of_day..to.end_of_day)

      unless ignore_group || group.blank?
        scope = scope.left_joins(:tournament_cc)
        scope = if group == GROUP_NONE
          # Faengt beides: kein CC-Zwilling (NULL durch den LEFT JOIN) und Zwilling ohne Typ.
          scope.where(tournament_ccs: {championship_type_cc_name: [nil, ""]})
        else
          scope.where(tournament_ccs: {championship_type_cc_name: group_rohwerte})
        end
      end

      unless ignore_discipline || discipline_name.blank?
        scope = scope.where(discipline_id: discipline_subtree_ids)
      end

      unless ignore_location || location_name.blank?
        scope = if location_name == LOCATION_NONE
          scope.where(location_id: nil)
        else
          scope.left_joins(:location).where(locations: {name: location_name})
        end
      end

      scope
    end

    # Die gewaehlte Disziplin UND alles darunter.
    #
    # ⚠️ Ein Namensvergleich reicht NICHT. Turniere haengen an Blatt-Disziplinen ("9-Ball"),
    # Ligen dagegen am Branch-Record selbst ("Pool"). Wer "Pool" waehlte, sah deshalb nur
    # Spieltage — "NDJM Pool 9-Ball" fiel raus, obwohl es Pool ist (Betreiber-Befund 2026-08-27).
    #
    # Ueber ALLE gleichnamigen Disziplinen, weil der Unique-Index auf (name, table_kind_id)
    # laeuft: derselbe Name kann fuer zwei Tischgroessen existieren.
    def discipline_subtree_ids
      @discipline_subtree_ids ||=
        Discipline.where(name: discipline_name).flat_map(&:subtree_ids).uniq.presence || [-1]
    end

    # Anzeigename einer Gruppe: doppelte Leerzeichen zusammengezogen.
    #
    # ⚠️ Gemessen am 2026-08-27: von 49 Rohwerten unterscheiden sich zwei NUR in der Anzahl der
    # Leerzeichen ("Deutsche Jugend Meisterschaft (DJM)" vs. "… Meisterschaft  (DJM)"). Ohne das
    # stuenden zwei optisch identische Knoepfe nebeneinander, die je die Haelfte der Turniere
    # zeigen.
    def gruppenname(rohwert)
      rohwert.to_s.squeeze(" ").strip.presence
    end

    # Alle Rohwerte, die auf den gewaehlten Anzeigenamen normalisieren — der Filter muss beide
    # Schreibweisen fangen. Die Werteliste ist klein (49 insgesamt), die Abfrage entsprechend billig.
    def group_rohwerte
      @group_rohwerte ||= TournamentCc.where.not(championship_type_cc_name: [nil, ""])
        .distinct.pluck(:championship_type_cc_name)
        .select { |v| gruppenname(v) == group }
        .presence || [group]
    end

    # Turniere des Zeitraums NACH dem Sparten-Fallback. Der Sparten-Abgleich laeuft Ruby-seitig
    # (er braucht die Disziplin-Wurzel, siehe `branch_of_tournament`) — deshalb muessen auch die
    # Selektor-Optionen durch DIESE Einheit, sonst boete der Disziplin-Selektor bei Sparte
    # "Karambol" munter Pool-Disziplinen an.
    def tournaments_filtered(ignore_group: false, ignore_discipline: false, ignore_location: false)
      scope = tournaments_in_scope(ignore_group: ignore_group, ignore_discipline: ignore_discipline,
        ignore_location: ignore_location)
        .includes(:discipline, :location, :tournament_cc)
      return scope.to_a if branch_names.empty?

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
        scope = scope.where(discipline_id: discipline_subtree_ids)
      end
      scope = scope.select { |l| matches_branch?(branch_of_league(l)) } if branch_names.any?
      scope
    end

    # Ligen, die im Zeitraum WIRKLICH Spieltage haben.
    #
    # ⚠️ `leagues_in_scope` allein reicht fuer den Disziplin-Selektor NICHT: es filtert die Ligen,
    # nicht ihre Spieltage. Gemessen am 2026-08-27 traegt der NBV 15 Ligen mit Disziplin
    # "Karambol", 18 mit "Karambol grosses Billard" und 27 mit "Karambol kleines Billard" — in
    # der Saison 26/27 aber NULL Spieltage (Saisonstart). Der Selektor bot diese Disziplinen an
    # und lieferte dann nichts. Angeboten wird nur, was auch etwas hergibt.
    def leagues_with_parties(ignore_discipline: false)
      leagues = Array(leagues_in_scope(ignore_discipline: ignore_discipline))
      return [] if leagues.empty?

      mit_spieltagen = Party.where(league_id: leagues.map(&:id))
        .where(date: from.beginning_of_day..to.end_of_day)
        .distinct.pluck(:league_id).to_set
      leagues.select { |l| mit_spieltagen.include?(l.id) }
    end

    def party_entries
      # Eine gewaehlte Gruppe ist eine reine Turnier-Achse — Spieltage tragen keine Kategorie.
      # Der Controller setzt `kind` dann sichtbar auf "single"; hier reicht der Kind-Schalter.
      return [] unless parties?

      leagues = Array(leagues_in_scope)
      return [] if leagues.empty?

      by_league = leagues.index_by(&:id)
      parties = parties_in_scope(by_league.keys)
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

    # Spieltage im Zeitraum, mit Ortsfilter. Der Ort steht an der PARTY (jede Begegnung kann
    # woanders stattfinden), nicht an der Liga.
    def parties_in_scope(league_ids, ignore_location: false)
      scope = Party.where(league_id: league_ids)
        .where(date: from.beginning_of_day..to.end_of_day)

      unless ignore_location || location_name.blank?
        scope = if location_name == LOCATION_NONE
          scope.where(location_id: nil)
        else
          scope.left_joins(:location).where(locations: {name: location_name})
        end
      end

      scope
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
      name.present? && branch_names.any? { |gesucht| name.casecmp?(gesucht) }
    end

    def format_time(value)
      return nil if value.blank?

      formatted = value.strftime("%H:%M")
      (formatted == "00:00") ? nil : formatted
    end
  end
end
