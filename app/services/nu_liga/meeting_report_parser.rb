# frozen_string_literal: true

require "nokogiri"

module NuLiga
  # Parst den NuLiga-Spielbericht (groupMeetingReport) in strukturierte Einzelspiele.
  #
  # Struktur (Fixture test/snapshots/vcr/nuliga/03_groupMeetingReport_7112978.html) — WEICHT vom
  # LigaManager::MatchReportParser AB:
  # - table.result-set; Zeilen mit unterschiedlicher Zellenzahl (nach Größe unterscheiden).
  # - Kopfzeile [7]: td[1]=Heimteam, td[2]=Gastteam.
  # - Einzelspiel [6]: td[0]=Disziplin, td[1]=Heim, td[2]=Gast, td[3]=leer, td[4]=Sätze, td[5]=Partien.
  # - Einzelspiel mit Inline-Statistik [8] (z. B. "14.1"): td[3]="60:58 Bälle", td[4]="30:30 Aufn.",
  #   td[5]="7:4 HS", td[6]=Sätze, td[7]=Partien.
  # - Doppel: Disziplin endet auf "Doppel"; die Spieler-Zelle enthält ZWEI person-Links.
  # - Trennzeile [1] und Summen-Schlusszeile (leere Spielernamen) → keine Einzelspiele; die Summenzeile
  #   trägt in der letzten Zelle das Gesamt (z. B. "9:1") = final_result.
  class MeetingReportParser
    SCORE_RE = /(\d+)\s*:\s*(\d+)/

    def initialize(html)
      @doc = Nokogiri::HTML.fragment(html.to_s)
    end

    def parse
      table = @doc.css("table").first
      rows = table ? table.css("tr").to_a : []
      teams = header_teams(rows)
      {
        home_team: teams[0],
        guest_team: teams[1],
        final_result: final_result(rows),
        games: games(rows)
      }
    end

    private

    # Kopfzeile (nutzt <th>): Teamnamen in Spalte 1/2, Spalte 0 leer.
    def header_teams(rows)
      head = rows.find do |tr|
        cells = tr.css("td, th")
        cells.size >= 3 && cell(cells[0]).empty? && cell(cells[1]).present? && cell(cells[2]).present?
      end
      return [nil, nil] unless head

      cells = head.css("td, th")
      [cell(cells[1]), cell(cells[2])]
    end

    def games(rows)
      pos = 0
      rows.filter_map do |tr|
        tds = tr.css("td")
        next unless game_row?(tds)

        pos += 1
        build_game(tds, pos)
      end
    end

    # Einzelspiel-Zeile: 6 oder 8 Zellen, Disziplin in td[0] gesetzt, Spielernamen in td[1] vorhanden.
    def game_row?(tds)
      [6, 8].include?(tds.size) && cell(tds[0]).present? && cell(tds[1]).present?
    end

    def build_game(tds, pos)
      stats = (tds.size == 8) ? parse_stats(tds) : nil
      {
        position: pos,
        discipline: cell(tds[0]),
        home_players: players(tds[1]),
        guest_players: players(tds[2]),
        set_result: cell(tds[-2]),
        match_points: cell(tds[-1]),
        stats: stats
      }
    end

    # Spielernamen aus den person-Links der Zelle (1 = Einzel, 2 = Doppel). Fallback: Zell-Text.
    def players(td)
      links = td.css('a[href*="person"]')
      return links.map { |a| cell(a) } if links.any?

      text = cell(td)
      text.empty? ? [] : [text]
    end

    # Inline-Statistik der 8-Zellen-Zeile: Bälle/Aufnahmen/HS je Heim/Gast.
    def parse_stats(tds)
      balls = scores(tds[3])
      innings = scores(tds[4])
      hs = scores(tds[5])
      return nil unless balls || innings || hs

      {balls: balls, innings: innings, hs: hs}
    end

    def scores(td)
      m = cell(td).match(SCORE_RE)
      m && {home: m[1].to_i, guest: m[2].to_i}
    end

    # Endstand aus der Summen-Schlusszeile: [6]-Zeile mit leeren Spielernamen, letzte Zelle "H:G".
    def final_result(rows)
      row = rows.reverse.find do |tr|
        tds = tr.css("td")
        tds.size == 6 && cell(tds[0]).empty? && cell(tds[1]).empty? && cell(tds[-1]).match?(SCORE_RE)
      end
      return nil unless row

      m = cell(row.css("td")[-1]).match(SCORE_RE)
      {home: m[1].to_i, guest: m[2].to_i}
    end

    def cell(node)
      return "" unless node

      node.text.tr(" ", " ").gsub(/\s+/, " ").strip
    end
  end
end
