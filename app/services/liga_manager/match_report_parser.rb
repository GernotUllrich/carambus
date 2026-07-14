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

      table.css("tr").filter_map do |tr|
        cells = tr.css("td").map { |c| c.text.gsub(/\s+/, " ").strip }
        next unless cells.size == 6           # nur Match-Zeilen (nicht Gruppen-/Statistikzeilen)
        next unless cells[0].match?(/\A\d+\z/) # Positionsnummer (Header hat "#")
        next unless cells[3].match?(SET_RESULT_RE)

        {
          position: cells[0].to_i,
          discipline: cells[1],
          home_player: cells[2],
          set_result: cells[3].delete(" "),
          away_player: cells[4],
          match_points: cells[5].delete(" ")
        }
      end
    end
  end
end
