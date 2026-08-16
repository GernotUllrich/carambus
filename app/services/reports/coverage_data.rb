# frozen_string_literal: true

module Reports
  # Abdeckungsmatrix: wie viele Turniere bzw. Ligen liegen je Region, Saison und Disziplin-Zweig
  # im Bestand — und aus welcher Quelle. Reiner Lesezugriff, die Daten für `rake coverage:pages`.
  #
  # WARUM NICHT ÜBER `branch_id`: Die Spalte ist bei gesyncten GLOBALEN Records leer. Der
  # Version-Apply schreibt per `update_columns` und umgeht damit den `BranchTaggable`-Hook,
  # `LocalProtector` sperrt anschließend das Nachspeichern (die Begründung steht ausführlich in
  # branch.rb). Gemessen auf der Authority am 2026-08-06: 866 von 18 494 Turnieren und 608 von
  # 6 418 Ligen tragen sie überhaupt. Der Zweig wird deshalb — wie überall sonst im Code auch —
  # über die WURZEL DES DISZIPLIN-BAUMS aufgelöst (`Branch.discipline_ids_for`).
  #
  # Eine Zeile ohne Region fällt heraus (bei Turnieren die internationalen UMB-Datensätze), ebenso
  # eine Disziplin außerhalb der vier Zweig-Bäume. Beides wird in `meta` mitgezählt, damit die
  # Seite die Lücke ausweisen kann statt sie zu verschlucken.
  class CoverageData
    Result = Struct.new(:branches, :seasons, :regions, :cells, :sources, :meta, keyword_init: true)

    # Die Herkunft bestimmt `Provenance::Classifier` — dieselbe Stelle, die auch die Spalte
    # `source_kind` füllt (Phase 34-01). Damit können Report und Datenbestand nicht auseinanderlaufen.
    # Hier steht nur noch die Übersetzung in die Anzeige-Schlüssel dieser Seite.
    DISPLAY_KIND = {
      :club_cloud => :cc,
      :ba => :billard_area,
      :nu_liga => :nu_liga,
      :liga_manager => :liga_manager,
      :carambus => :carambus,
      :umb => :other,     # internationale Turniere tragen keine Region und fallen ohnehin heraus
      :none => :none,
      nil => :other    # URL vorhanden, Muster unbekannt
    }.freeze

    # Reihenfolge der Auswertung/Anzeige; :none = Record ohne jede Herkunftsspur.
    SOURCE_KINDS = %i[cc billard_area nu_liga liga_manager carambus other none].freeze

    def self.for(model)
      new(model).call
    end

    def initialize(model)
      @model = model
    end

    def call
      cells = Hash.new(0)
      sources = Hash.new { |h, k| h[k] = Hash.new(0) }
      unmapped = 0

      @model.where.not(region_id: nil).pluck(:id, :region_id, :season_id, :discipline_id, :source_url, :ba_id)
        .each do |id, region_id, season_id, discipline_id, source_url, ba_id|
        branch_id = branch_of_discipline[discipline_id]
        next unmapped += 1 if branch_id.nil? || season_id.nil?

        key = [branch_id, region_id, season_id]
        cells[key] += 1
        sources[key][source_kind(source_url, ba_id, cc_ids.include?(id))] += 1
      end

      Result.new(
        branches: ordered_branches.map { |b| {id: b.id, name: b.name} },
        seasons: seasons_for(cells),
        regions: regions_for(cells),
        cells: stringify(cells),
        sources: stringify(sources),
        meta: meta(cells, sources, unmapped)
      )
    end

    # Regionen, die Carambus HEUTE aus einer ClubCloud scrapet. Kein historischer Wert: TBV stand
    # bis zum LigaManager-Cutover (v0.4) hier drin, BBV wurde nie über die CC angebunden.
    def self.cc_region?(shortname)
      Region::SHORTNAMES_CC.key?(shortname.to_s)
    end

    private

    # Anzeigereihenfolge der Zweige: nach Größe im deutschen Spielbetrieb, nicht nach id — so
    # steht oben, was die meisten Leser zuerst suchen. Unbekannte Zweige hängen hinten an.
    BRANCH_ORDER = %w[Karambol Pool Snooker Kegel].freeze

    # Kaskade `source_url` > `ba_id` > `*_cc`, begruendet in `Provenance::Classifier`.
    #
    # OHNE `source_url`, ABER MIT `ba_id` = BillardArea (Betreiber 2026-08-06). Die Quelle ist
    # nicht mehr online, deshalb gibt es dafuer keine URL. Gemessen: bei den Ligen tragen ALLE
    # 4 558 Datensaetze ohne source_url eine ba_id und enden exakt mit 2021/2022; bei den Turnieren
    # 12 974 von 13 342. Die beiden Felder schliessen einander sonst aus — von 4 719 Turnieren mit
    # source_url hat kein einziges eine ba_id.
    def source_kind(source_url, ba_id, cc_present)
      DISPLAY_KIND.fetch(
        Provenance::Classifier.call(source_url: source_url, ba_id: ba_id, cc_present: cc_present)
      )
    end

    # Die dritte Stufe der Kaskade: Datensaetze, die weder eine URL noch eine `ba_id` tragen, aber
    # einen `tournament_cc`/`league_cc` haben — 366 Turniere im Bestand. Ohne diese Abfrage wies der
    # Report sie als "keine Herkunftsspur" aus, obwohl sie belegbar aus einer CC stammen.
    # `LeagueCc` UNSCOPED plucken: `League#league_cc` ist auf `context: "nbv"` gescopt.
    def cc_ids
      @cc_ids ||= ((@model <= Tournament) ? TournamentCc.distinct.pluck(:tournament_id) : LeagueCc.distinct.pluck(:league_id)).compact.to_set
    end

    def stringify(hash)
      hash.transform_keys { |b, r, s| "#{b}|#{r}|#{s}" }
    end

    def ordered_branches
      @ordered_branches ||= Branch.all.sort_by { |b| [BRANCH_ORDER.index(b.name) || 99, b.name.to_s] }
    end

    def branch_of_discipline
      @branch_of_discipline ||= ordered_branches.each_with_object({}) do |branch, map|
        Branch.discipline_ids_for(branch.id).each { |discipline_id| map[discipline_id] = branch.id }
      end
    end

    # Chronologisch über den NAMEN, nicht über id oder ba_id — die sind durch das internationale
    # Scrapen verrutscht (dieselbe Lehre wie in Season.recent_valid).
    def seasons_for(cells)
      Season.where(id: cells.keys.map { |k| k[2] }.uniq)
        .sort_by { |s| s.name.to_s }
        .map { |s| {id: s.id, name: s.name} }
    end

    # Nach Gesamtmenge absteigend: die Zeilen mit Substanz oben, die dünnen unten — dort sieht man
    # die Lücken am schnellsten. `cc` sagt, ob Carambus die Region heute aus einer CC scrapet.
    def regions_for(cells)
      totals = Hash.new(0)
      cells.each { |(_b, region_id, _s), n| totals[region_id] += n }

      Region.where(id: totals.keys)
        .sort_by { |r| -totals[r.id] }
        .map { |r| {id: r.id, short: r.shortname, name: r.name, cc: self.class.cc_region?(r.shortname)} }
    end

    def meta(cells, sources, unmapped)
      totals = Hash.new(0)
      sources.each_value { |kinds| kinds.each { |kind, n| totals[kind] += n } }

      {
        counted: cells.values.sum,
        total: @model.count,
        without_region: @model.where(region_id: nil).count,
        without_discipline: @model.where(discipline_id: nil).count,
        with_branch_id: @model.where.not(branch_id: nil).count,
        unmapped: unmapped,
        sources: SOURCE_KINDS.to_h { |kind| [kind, totals[kind]] }
      }
    end
  end
end
