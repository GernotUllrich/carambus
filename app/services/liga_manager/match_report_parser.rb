# frozen_string_literal: true

require "nokogiri"

module LigaManager
  # Parst den HTML-Spielbericht der LigaManager-API
  # (results/public-view-by-matchplan) in strukturierte Einzelpartien.
  #
  # Struktur (siehe test/snapshots/vcr/ligamanager/results_by-matchplan_30.html):
  # - Endstand im Text: "Endstand H : G"
  # - Ergebnis-Tabelle: Match-Zeilen = 6 Zellen [Pos, Disziplin, Heim, Erg., Gast, Punkte];
  #   Gruppen-Zeilen ("Hinrunde"/"Rückrunde") = 1 Zelle; Statistik-Zeilen = 4 Zellen (übersprungen).
  class MatchReportParser
    FINAL_SCORE_RE = /Endstand\s+(\d+)\s*:\s*(\d+)/
    SET_RESULT_RE = /\A\d+\s*:\s*\d+\z/
    # Statistikzeile je Einzelpartie, z. B. "Punkte × 1 41 : 200 Aufn. 18 / 18 HS 8 / 43 GD 2.28 / 11.11"
    # (× = U+00D7). Reihenfolge der Zahlen: Faktor, Bälle H:G, Aufnahmen H/G, Höchstserie H/G, Schnitt H/G.
    STATS_RE = /Punkte\s*×\s*(\d+)\s+(\d+)\s*:\s*(\d+)\s+Aufn\.\s*(\d+)\s*\/\s*(\d+)\s+HS\s*(\d+)\s*\/\s*(\d+)\s+GD\s*([\d.]+)\s*\/\s*([\d.]+)/

    def initialize(html)
      @doc = Nokogiri::HTML.fragment(html.to_s)
    end

    def parse
      {final_score: parse_final_score, games: parse_games}
    end

    private

    def parse_final_score
      m = @doc.text.match(FINAL_SCORE_RE)
      return nil unless m

      {home: m[1].to_i, guest: m[2].to_i}
    end

    def parse_games
      table = @doc.css("table").first
      return [] unless table

      rows = table.css("tr").to_a
      games = []
      rows.each_with_index do |tr, i|
        cells = tr.css("td").map { |c| c.text.gsub(/\s+/, " ").strip }
        next unless cells.size == 6           # nur Match-Zeilen (nicht Gruppen-/Statistikzeilen)
        next unless cells[0].match?(/\A\d+\z/) # Positionsnummer (Header hat "#")
        next unless cells[3].match?(SET_RESULT_RE)

        games << {
          position: cells[0].to_i,
          discipline: cells[1],
          home_player: cells[2],
          set_result: cells[3].delete(" "),
          away_player: cells[4],
          match_points: cells[5].delete(" "),
          stats: parse_stats(rows[i + 1]) # Statistik-Werte aus der folgenden Zeile (nil, wenn keine)
        }
      end
      games
    end

    # Parst die Statistik-Folgezeile (Bälle/Aufnahmen/HS/GD je Heim/Gast). nil, wenn keine
    # passende 4-Zellen-Zeile folgt oder der Statistik-String nicht dem Muster entspricht.
    def parse_stats(tr)
      return nil unless tr

      cells = tr.css("td").map { |c| c.text.gsub(/\s+/, " ").strip }
      return nil unless cells.size == 4

      m = cells[2].match(STATS_RE)
      return nil unless m

      {
        factor: m[1].to_i,
        balls: {home: m[2].to_i, guest: m[3].to_i},
        innings: {home: m[4].to_i, guest: m[5].to_i},
        hs: {home: m[6].to_i, guest: m[7].to_i},
        gd: {home: m[8].to_f, guest: m[9].to_f}
      }
    end
  end
end
