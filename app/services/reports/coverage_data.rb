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

    # Herkunft am URL-MUSTER der Quellsysteme erkannt, nicht an der Domain: jeder Landesverband
    # betreibt seine ClubCloud unter eigenem Namen (ndbv.de, westfalenbillard.net, blv-sa.de …),
    # aber alle liefern dieselben Skripte aus. Eine Domain-Liste wäre schon beim nächsten Umzug
    # falsch — das Muster hält.
    SOURCE_PATTERNS = {
      cc: ["sb_meisterschaft.php", "sb_spielplan.php"],
      liga_manager: ["billard.center"],
      nu_liga: ["liga.nu", "nuLigaBILLARD"],
      carambus: ["carambus.de"]
    }.freeze

    # Reihenfolge der Auswertung/Anzeige; :none = Record ohne `source_url`.
    SOURCE_KINDS = %i[cc nu_liga liga_manager carambus other none].freeze

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

      @model.where.not(region_id: nil).pluck(:region_id, :season_id, :discipline_id, :source_url)
        .each do |region_id, season_id, discipline_id, source_url|
        branch_id = branch_of_discipline[discipline_id]
        next unmapped += 1 if branch_id.nil? || season_id.nil?

        key = [branch_id, region_id, season_id]
        cells[key] += 1
        sources[key][source_kind(source_url)] += 1
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

    def source_kind(source_url)
      return :none if source_url.blank?

      SOURCE_PATTERNS.each do |kind, needles|
        return kind if needles.any? { |needle| source_url.include?(needle) }
      end
      :other
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
