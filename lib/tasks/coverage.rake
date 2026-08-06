# frozen_string_literal: true

# Erzeugt die statischen Bestandsübersichten unter public/uebersichten/ neu.
#
#   bin/rails coverage:pages          # schreibt die drei Seiten
#   OUT=/tmp/x bin/rails coverage:pages
#
# STRIKT LESEND auf der Datenbank — geschrieben wird ausschliesslich ins Ausgabeverzeichnis.
# Sinnvoll auf der AUTHORITY: nur dort liegt der vollstaendige globale Bestand.
#
# Die Seiten sind Momentaufnahmen und rechnen sich nicht selbst neu; dieser Task ist der Weg,
# sie zu aktualisieren. Nach dem Lauf muessen die Dateien noch deployt werden (sie liegen unter
# public/ und reisen mit dem naechsten Capistrano-Deploy).
namespace :coverage do
  desc "Bestandsuebersichten (Turniere/Ligen je Region, Saison, Zweig) nach public/uebersichten schreiben"
  task pages: :environment do
    require "erb"
    require "json"

    out_dir = Pathname.new(ENV["OUT"].presence || Rails.root.join("public/uebersichten"))
    FileUtils.mkdir_p(out_dir)
    generated_at = I18n.l(Time.zone.today, format: "%-d. %B %Y", locale: :de)

    tournaments = Reports::CoverageData.for(Tournament)
    leagues = Reports::CoverageData.for(League)

    write_page(out_dir.join("turnier-abdeckung.html"),
      title: "Turnier-Abdeckung — Regionen, Saisons, Disziplin-Zweige",
      headline: "Turnier-Abdeckung nach Region, Saison und Disziplin-Zweig",
      lede: tournament_lede(tournaments),
      footnote_heading: "Woher die Zahlen kommen",
      footnotes: tournament_footnotes(tournaments) + source_footnotes(tournaments, "Turniere"),
      item_label: "Turniere",
      data: tournaments, generated_at: generated_at)

    write_page(out_dir.join("liga-abdeckung.html"),
      title: "Liga-Abdeckung — Regionen, Saisons, Disziplin-Zweige",
      headline: "Liga-Abdeckung nach Region, Saison und Disziplin-Zweig",
      lede: league_lede(leagues),
      footnote_heading: "Woher die Zahlen kommen — und was gegenüber den Turnieren auffällt",
      footnotes: league_footnotes(tournaments, leagues) + source_footnotes(leagues, "Ligen"),
      item_label: "Ligen",
      data: leagues, generated_at: generated_at)

    write_index(out_dir.join("index.html"), tournaments, leagues, generated_at)

    puts "Geschrieben nach #{out_dir}:"
    [tournaments, leagues].zip(%w[Turniere Ligen]).each do |data, label|
      m = data.meta
      puts format("  %-9s %s gezaehlt · %s Regionen · %s Saisons · %s ohne Region · %s nicht zuordenbar",
        label, num(m[:counted]), data.regions.size, data.seasons.size,
        num(m[:without_region]), num(m[:unmapped]))
    end
  end
end

# --- Aufbereitung -------------------------------------------------------------------------------
#
# Die Fliesstexte entstehen aus den GEMESSENEN Zahlen, damit die Seite beim naechsten Lauf nicht
# eine alte Behauptung mitschleppt. Nur die deutenden Saetze sind fest — sie sind Aussagen ueber
# die Datenherkunft, die sich nicht aus den Zahlen ergeben.

def num(n) = ActiveSupport::NumberHelper.number_to_delimited(n, delimiter: " ")

def branch_totals(data)
  data.branches.to_h do |b|
    total = 0
    regions = Set.new
    data.cells.each do |key, n|
      branch_id, region_id, = key.split("|")
      next unless branch_id.to_i == b[:id]

      total += n
      regions << region_id
    end
    [b[:name], {total: total, regions: regions.size}]
  end
end

def tournament_lede(data)
  m = data.meta
  "Gezählt werden alle Turniere mit Regionszuordnung im Authority-Bestand: <b>#{num(m[:counted])}</b> " \
    "Turniere über <b>#{data.regions.size} Regionen</b>, <b>#{data.seasons.size} Saisons</b> und " \
    "#{data.branches.size} Zweige. Der Zweig wird über die <b>Wurzel des Disziplin-Baums</b> bestimmt, " \
    "nicht über die Spalte <code>branch_id</code> — die ist bei gesyncten globalen Records leer."
end

def league_lede(data)
  m = data.meta
  parties = Party.where.not(league_id: nil).count
  vollstaendig = m[:without_region].zero? && m[:without_discipline].zero?
  "<b>#{num(m[:counted])}</b> Ligen über <b>#{data.regions.size} Regionen</b>, " \
    "<b>#{data.seasons.size} Saisons</b> und #{data.branches.size} Zweige" \
    "#{" — und anders als bei den Turnieren trägt hier <b>jede einzelne</b> eine Region und eine Disziplin" if vollstaendig}. " \
    "An den Ligen hängen <b>#{num(parties)} Partien</b>. Der Zweig kommt wieder aus der " \
    "<b>Wurzel des Disziplin-Baums</b>, nicht aus <code>branch_id</code>."
end

def li(text) = "      <li>#{text}</li>\n"

def branch_id_note(model_label, data)
  m = data.meta
  "nur #{num(m[:with_branch_id])} von #{num(m[:total])} #{model_label} tragen sie überhaupt"
end

def tournament_footnotes(data)
  m = data.meta
  li("<b>Zweig-Zuordnung:</b> über <code>Discipline#root</code>, wie es <code>Branch.discipline_ids_for</code> " \
     "im Code tut. Die Spalte <code>tournaments.branch_id</code> taugt dafür nicht: der Version-Apply schreibt " \
     "per <code>update_columns</code> und umgeht den <code>BranchTaggable</code>-Hook, <code>LocalProtector</code> " \
     "sperrt das Nachspeichern — sie bleibt bei globalen Records NULL. #{branch_id_note("Turnieren", data).capitalize}.") +
    li("<b>Nicht in der Matrix:</b> #{num(m[:without_region])} Turniere ohne <code>region_id</code> — im " \
       "Wesentlichen die internationalen UMB-Turniere. Sie sind auch der Grund, warum spätere Saisons hier " \
       "fehlen können, obwohl dort schon Turniere stehen.") +
    li("<b>Randfälle:</b> #{num(m[:unmapped])} Turniere hängen an einer Disziplin außerhalb der Zweig-Bäume, " \
       "#{num(m[:without_discipline])} haben gar keine Disziplin. Beide bleiben unberücksichtigt.") +
    li("<b>Eine leere Zelle heißt nicht „kein Turnier gespielt“</b>, sondern „in Carambus nicht erfasst“. " \
       "Der Unterschied ist genau das, was diese Übersicht zeigen soll.")
end

def league_footnotes(tournaments, leagues)
  lm = leagues.meta
  tm = tournaments.meta
  lb = branch_totals(leagues)
  tb = branch_totals(tournaments)

  # Der auffälligste Kontrast wird GEMESSEN, nicht behauptet: welcher Zweig deckt im Ligabetrieb
  # mehr Regionen ab als im Turnierbetrieb, welcher deutlich weniger.
  breiter = lb.select { |name, v| tb[name] && v[:regions] > tb[name][:regions] }
    .max_by { |_n, v| v[:regions] }
  schmaler = lb.select { |name, v| tb[name] && v[:regions] < tb[name][:regions] }
    .min_by { |_n, v| v[:regions] }

  notes = li("<b>Vollständigkeit:</b> #{num(lm[:without_region])} Ligen ohne <code>region_id</code>, " \
             "#{num(lm[:without_discipline])} ohne <code>discipline_id</code> — bei den Turnieren fehlt " \
             "#{num(tm[:without_region])}-mal die Region. Ligen entstehen ausschließlich über die " \
             "Verbands-Scrapes (ClubCloud, LigaManager, NuLiga), die beides immer mitliefern; Turniere kommen " \
             "zusätzlich aus internationalen Quellen ohne Regionsbezug.")
  notes += li("<b>Zweig-Zuordnung wie bei den Turnieren</b> über <code>Discipline#root</code>. Auch hier ist " \
              "<code>leagues.branch_id</code> unbrauchbar: #{branch_id_note("Ligen", leagues)}.")
  if breiter && schmaler
    notes += li("<b>Die Zweige verteilen sich anders als bei den Turnieren.</b> #{breiter[0]} ist im Ligabetrieb " \
                "mit <b>#{breiter[1][:regions]} von #{leagues.regions.size}</b> Regionen breiter aufgestellt als " \
                "im Turnierbestand (#{tb[breiter[0]][:regions]}). #{schmaler[0]} geht den umgekehrten Weg: " \
                "#{tb[schmaler[0]][:regions]} Regionen mit Turnieren, aber nur <b>#{schmaler[1][:regions]}</b> mit Ligen.")
  end
  notes + li("<b>Auch hier heißt eine leere Zelle „in Carambus nicht erfasst“</b>, nicht „kein Spielbetrieb“ — " \
             "eine Aussage über die Datenquelle, nicht über den Verband.")
end

# Herkunft: was stammt NICHT aus der ClubCloud. Die Zahlen kommen aus dem gemessenen
# `source_url`-Muster, die Regionsliste aus `Region::SHORTNAMES_CC` — also aus dem Code, der den
# Scrape tatsächlich steuert, nicht aus einer gepflegten Nebenliste.
def source_footnotes(data, label)
  s = data.meta[:sources]
  nicht_cc = s[:nu_liga] + s[:liga_manager] + s[:carambus] + s[:other]
  ohne_cc_anschluss = data.regions.reject { |r| r[:cc] }.map { |r| r[:short] }

  notes = li("<b>Was nicht aus der ClubCloud stammt</b> ist farbig markiert — im Modus „Quelle“ " \
             "flächig, sonst als Balken links in der Zelle. Nachweislich nicht aus einer CC stammen " \
             "<b>#{num(nicht_cc)}</b> #{label}: #{num(s[:nu_liga])} aus NuLiga, " \
             "#{num(s[:liga_manager])} aus dem LigaManager, #{num(s[:carambus])} aus Carambus selbst " \
             "(CC-loser Ablauf), #{num(s[:other])} aus sonstigen Quellen. Aus einer ClubCloud kommen " \
             "#{num(s[:cc])}, erkannt am URL-Muster des Quellsystems.")
  notes += li("<b>Die größte Gruppe trägt gar keine Quellenangabe:</b> #{num(s[:none])} #{label} " \
              "ohne <code>source_url</code> — Altbestand, dessen Herkunft sich aus dem Datensatz nicht " \
              "mehr ableiten lässt. Diese Zellen sind schraffiert und bleiben ungefärbt; sie als " \
              "„ClubCloud“ zu zählen wäre geraten.")
  unless ohne_cc_anschluss.empty?
    notes += li("<b>Ohne CC-Anschluss</b> (Kennzeichnung an der Region): " \
                "#{ohne_cc_anschluss.join(", ")}. Diese Verbände stehen nicht in " \
                "<code>Region::SHORTNAMES_CC</code>, werden also heute nicht aus einer ClubCloud " \
                "gescrapt — bei TBV etwa seit dem LigaManager-Cutover, weshalb dort trotzdem älterer " \
                "CC-Bestand liegt.")
  end
  notes
end

# --- Ausgabe ------------------------------------------------------------------------------------

def render(template, bindings)
  path = Rails.root.join("lib/templates/coverage/#{template}")
  ERB.new(File.read(path), trim_mode: "-").result_with_hash(bindings)
end

def write_page(path, data:, **copy)
  payload = {
    branches: data.branches,
    seasons: data.seasons,
    regions: data.regions,
    cells: data.cells,
    sources: data.sources
  }
  File.write(path, render("page.html.erb", copy.merge(payload_json: JSON.generate(payload))))
end

def write_index(path, tournaments, leagues, generated_at)
  parties = Party.where.not(league_id: nil).count
  File.write(path, render("index.html.erb",
    generated_at: generated_at,
    tournament_stats: "#{num(tournaments.meta[:counted])} Turniere · #{tournaments.regions.size} Regionen · " \
                      "#{tournaments.seasons.size} Saisons",
    league_stats: "#{num(leagues.meta[:counted])} Ligen · #{num(parties)} Partien · #{leagues.regions.size} Regionen"))
end
