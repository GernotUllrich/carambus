# frozen_string_literal: true

# Daten für die Übersicht „Liga-Einzelspiele je Region“: je Region eine Zeile pro Liga (Name, Staffel,
# Disziplin) und eine Zelle pro Saison mit [Ligen, Partien, PartyGames, Quelle(n), Dublette 0/1].
# Frühere Namen kommen aus leagues.synonyms, Dubletten aus einem Dry-Run des League::SeriesUnifier.
# Rein lesend. Die HTML-Seite dazu: lib/templates/league_series_table.html (rake leagues:series_table).
class League::SeriesTable
  SOURCES = {"ba" => "BA", "club_cloud" => "CC", "nu_liga" => "NuLiga", "liga_manager" => "LM"}.freeze

  # Offene Fälle aus der Reihen-Bereinigung (2026-11-24): [Region, Namensmuster, Hinweis]. Vermutungen,
  # keine Fachregeln. Ist ein Fall entschieden, wird er Regel im SeriesUnifier oder fällt hier weg.
  NOTES = [
    ["BLVN", /\APooll /, "Tippfehler im Namen? Vermutlich die zweite Landesliga im Bezirk OH (analog „Kreisliga OH“)"],
    ["BLVN", /\AKreisliga OH\z/, "Zweite Kreisliga im Bezirk OH (Staffel „2 OH“); eine Liga trägt „Pool Kreisliga 1“ als Staffel"],
    ["BLVN", /Oberliga (Dreiband|Mehrkampf)\z/, "Gleiche Reihe unter anderer Disziplin? „Oberliga …“ (Karambol) vs. „BLVN Oberliga …“ (großes/kleines Billard)"],
    ["BLVN", /\ANeue Liga\z/, "Platzhalter aus der Quelle"],
    ["BVS", /\ANeue Liga\z/, "Platzhalter aus der Quelle"],
    ["BLVN", /\AJugend-Mannschaft\z/, "Staffel „Weserbergland A/B“ — eigene Reihe, nur zur Kontrolle"],
    ["SBV", /Eurokegel/, "Wortstellung: „Eurokegel-Oberliga“ und „Oberliga Eurokegel“ — dieselbe Reihe?"],
    ["SBV", /\ALandesliga (Nord-West|Süd-Ost)\z/, "Staffel im Namen; die Reihe „Landesliga“ führt nur West/Ost"],
    ["BVS", /\AKreisliga [AB]\z/, "Staffel im Namen; die Reihe „Kreisliga“ führt keine Staffel A/B"],
    ["BVW", /\AWPBV (Bezirks|Kreis|Landes)liga\z/, "Staffel-Kürzel BL-/KL-/LL-1 neben „Staffel 1“ bzw. „- 1“ — gleiche Staffeln?"],
    ["BVW", /\ABVW .+ [AB] (Freie Partie|Dreiband|Zweikampf)\z/, "Staffel steht vor der Disziplin im Namen — gehört zur Reihe ohne Buchstaben"],
    ["BBV", /\ABayernpokal\z/, "Rundennummer: „2 Achtelfinale“ neben „Achtelfinale“"]
  ].freeze

  def call
    parties = Party.group(:league_id).count
    games = PartyGame.joins(:party).group("parties.league_id").count
    dups = League::SeriesUnifier.new.call.series.flat_map(&:duplicates).map { |c| c.league.id }.to_set

    data = Hash.new { |h, k| h[k] = {seasons: Set.new, rows: {}} }
    League.where(organizer_type: "Region").includes(:organizer, :season, :discipline).find_each do |l|
      reg = data[l.organizer.shortname]
      season = l.season.name
      reg[:seasons] << season
      name = l.read_attribute(:name).to_s
      row = reg[:rows][[name, l.staffel_text.to_s, l.discipline&.name.to_s]] ||= {cells: {}, former: Set.new}
      cell = row[:cells][season] ||= [0, 0, 0, Set.new, 0]
      cell[0] += 1
      cell[1] += parties.fetch(l.id, 0)
      cell[2] += games.fetch(l.id, 0)
      cell[3] << SOURCES.fetch(l.source_kind.to_s, l.source_kind.presence || "?")
      cell[4] = 1 if dups.include?(l.id)
      row[:former].merge(l.synonym_list - [name])
    end

    data.sort.to_h { |reg, r| [reg, region_json(reg, r)] }
  end

  private

  # Format von data.json: {"seasons" => [neueste zuerst], "rows" => [[Name, "Staffel · Disziplin",
  # {Saison => Zelle}, [frühere Namen], Hinweis]]}
  def region_json(reg, r)
    rows = r[:rows].sort_by { |(n, st, d), _| [n.downcase, st.downcase, d] }.map do |(n, st, d), row|
      cells = row[:cells].transform_values { |c| [c[0], c[1], c[2], c[3].to_a.sort.join("/"), c[4]] }
      note = NOTES.find { |rg, re, _| rg == reg && n.match?(re) }&.last
      [n, [st.presence, d.presence].compact.join(" · "), cells, row[:former].to_a.sort, note]
    end
    {"seasons" => r[:seasons].to_a.sort.reverse, "rows" => rows}
  end
end
