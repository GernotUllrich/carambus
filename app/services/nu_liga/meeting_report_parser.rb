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

    # Einzelspiel-Zeile: Disziplin in td[0] gesetzt, Spielernamen in td[1] vorhanden.
    # 6 = ohne Statistik; 8 = Pool/Snooker mit Inline-Statistik (Bälle/Aufn./HS);
    # 9 = Karambol (Dreiband): zusätzliche GD-Spalte (Generaldurchschnitt) zwischen HS und Sätzen.
    def game_row?(tds)
      [6, 8, 9].include?(tds.size) && cell(tds[0]).present? && cell(tds[1]).present?
    end

    def build_game(tds, pos)
      stats = (tds.size >= 8) ? parse_stats(tds) : nil
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

    # Inline-Statistik: Bälle/Aufnahmen/HS je Heim/Gast (td[3..5]); bei Karambol (9 Zellen) zusätzlich
    # der Generaldurchschnitt (GD, td[6], Dezimalzahl mit Komma, z. B. „1,142:0,342").
    def parse_stats(tds)
      balls = scores(tds[3])
      innings = scores(tds[4])
      hs = scores(tds[5])
      gd = (tds.size == 9) ? decimal_scores(tds[6]) : nil
      return nil unless balls || innings || hs || gd

      {balls: balls, innings: innings, hs: hs, gd: gd}.compact
    end

    def scores(td)
      m = cell(td).match(SCORE_RE)
      m && {home: m[1].to_i, guest: m[2].to_i}
    end

    # Karambol-GD: „1,142:0,342" (Komma-Dezimal) → {home: 1.142, guest: 0.342}.
    def decimal_scores(td)
      m = cell(td).match(/([\d,]+)\s*:\s*([\d,]+)/)
      m && {home: m[1].tr(",", ".").to_f, guest: m[2].tr(",", ".").to_f}
    end

    # Endstand aus der Summen-Schlusszeile: Spalte 0 leer (keine Disziplin → kein Einzelspiel),
    # letzte Zelle "H:G". Pool/Snooker = 6 Zellen (Spielernamen leer); Karambol = 7 Zellen (td[1]/[2]
    # tragen die Ball-Summen) — daher NUR td[0] als Leer-Diskriminator, nicht td[1].
    def final_result(rows)
      row = rows.reverse.find do |tr|
        tds = tr.css("td")
        [6, 7].include?(tds.size) && cell(tds[0]).empty? && cell(tds[-1]).match?(SCORE_RE)
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
