# frozen_string_literal: true

module Reports
  # Abdeckungsmatrix: wie viele Turniere bzw. Ligen liegen je Region, Saison und Disziplin-Zweig
  # im Bestand. Reiner Lesezugriff — die Daten für `rake coverage:pages`.
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
    Result = Struct.new(:branches, :seasons, :regions, :cells, :meta, keyword_init: true)

    # model: Tournament oder League (beide tragen region_id, season_id, discipline_id)
    def self.for(model)
      new(model).call
    end

    def initialize(model)
      @model = model
    end

    def call
      counts = @model.where.not(region_id: nil).group(:region_id, :season_id, :discipline_id).count

      cells = Hash.new(0)
      unmapped = 0
      counts.each do |(region_id, season_id, discipline_id), n|
        branch_id = branch_of_discipline[discipline_id]
        next unmapped += n if branch_id.nil? || season_id.nil?

        cells[[branch_id, region_id, season_id]] += n
      end

      Result.new(
        branches: ordered_branches.map { |b| {id: b.id, name: b.name} },
        seasons: seasons_for(cells),
        regions: regions_for(cells),
        cells: cells.transform_keys { |b, r, s| "#{b}|#{r}|#{s}" },
        meta: meta(cells, unmapped)
      )
    end

    private

    # Anzeigereihenfolge der Zweige: nach Größe im deutschen Spielbetrieb, nicht nach id — so
    # steht oben, was die meisten Leser zuerst suchen. Unbekannte Zweige hängen hinten an.
    BRANCH_ORDER = %w[Karambol Pool Snooker Kegel].freeze

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
    # die Lücken am schnellsten.
    def regions_for(cells)
      totals = Hash.new(0)
      cells.each { |(_b, region_id, _s), n| totals[region_id] += n }

      Region.where(id: totals.keys)
        .sort_by { |r| -totals[r.id] }
        .map { |r| {id: r.id, short: r.shortname, name: r.name} }
    end

    def meta(cells, unmapped)
      {
        counted: cells.values.sum,
        total: @model.count,
        without_region: @model.where(region_id: nil).count,
        without_discipline: @model.where(discipline_id: nil).count,
        with_branch_id: @model.where.not(branch_id: nil).count,
        unmapped: unmapped
      }
    end
  end
end
