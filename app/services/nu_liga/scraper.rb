# frozen_string_literal: true

module NuLiga
  # Read-only Scraper für die NuLiga-Struktur-Endpunkte (Ligen-Liste + Liga-Tabelle/Standings).
  # federation/season-parametrisiert; liefert reine Hashes/Arrays (KEIN DB-Zugriff).
  # Vorlage: LigaManager::Scraper (Struktur) + League::BbvScraper (NuLiga-Tabellen-Parse).
  # Tiefen-Endpunkte (Spielplan/Spielbericht/Roster) → Plan 14-02.
  class Scraper
    BRANCHES = %w[Pool Snooker Karambol].freeze

    def initialize(federation:, season:, client: Client.new)
      @federation = federation
      @season = season
      @client = client
    end

    # Ligen (groups) einer Sparte aus der leaguePage: [{group_id:, name:, url:}, ...]
    def leagues(branch)
      doc = @client.get_doc("leaguePage", championship: championship(branch))
      doc.css('a[href*="groupPage"]').filter_map do |a|
        href = a["href"].to_s
        gid = href[/group=(\d+)/, 1]
        next unless gid

        {group_id: gid.to_i, name: a.text.strip, url: href}
      end.uniq { |h| h[:group_id] }
    end

    # Eine Liga (group): Name + Standings-Tabelle mit Teams. branch wird für den championship-Param
    # gebraucht (der Aufrufer kennt ihn aus #leagues).
    # { group_id:, name:, teams: [{teamtable_id:, name:, rank:, data:{...}}, ...] }
    def group(group_id, branch:)
      doc = @client.get_doc("groupPage", championship: championship(branch), group: group_id)
      {group_id: group_id.to_i, name: group_name(doc), teams: standings(doc)}
    end

    # Spielplan einer Liga (groupPage&displayDetail=meetings): Liste der Begegnungen mit meeting-ID.
    # [{meeting_id:, date:, home_team:, guest_team:, result:}, ...] — nur Zeilen mit
    # groupMeetingReport-Link (gespielte/berichtete Begegnungen); reine Hashes, kein DB-Zugriff.
    def meetings(group_id, branch:)
      doc = @client.get_doc("groupPage", championship: championship(branch), group: group_id, displayDetail: "meetings")
      table = doc.css("table").first
      return [] unless table

      table.css("tr").filter_map { |tr| meeting_row(tr) }
    end

    # Spielbericht einer Begegnung (groupMeetingReport): Einzelspiele inkl. Doppel + Inline-Statistik.
    # Delegiert an NuLiga::MeetingReportParser. group_id/branch für die championship-/group-Params.
    def meeting_report(meeting_id, group_id:, branch:)
      html = @client.get_html("groupMeetingReport", meeting: meeting_id, championship: championship(branch), group: group_id)
      MeetingReportParser.new(html).parse
    end

    # Team-Detail (teamPortrait): eigener Verein (NuLiga-interne club_id ≠ Carambus cc_id) + Name.
    # { teamtable_id:, name:, club: {club_id:, name:} }
    def team(teamtable_id, group_id:, branch:)
      doc = @client.get_doc("teamPortrait", teamtable: teamtable_id, pageState: "vorrunde",
        championship: championship(branch), group: group_id)
      {teamtable_id: teamtable_id.to_i, name: team_name(doc), club: own_club(doc)}
    end

    # Roster/Spieler-Rangliste einer Liga (groupPlayerRankingLists): Spieler ↔ Team (namensbasiert).
    # [{person_id:, name:, team_name:}, ...] — Basis für Seeding-Reconcile (Phase 16).
    def player_ranking(group_id, branch:)
      doc = @client.get_doc("groupPlayerRankingLists", type: "rankingPoints",
        championship: championship(branch), group: group_id)
      table = doc.css("table").first
      return [] unless table

      table.css("tr").filter_map { |tr| ranking_row(tr) }
    end

    private

    # Eine Spielplan-Zeile → Begegnung oder nil (Header/Trenner/ungespielt ohne meeting-Link).
    # Robust: die Ergebnis-Zelle ist die mit dem groupMeetingReport-Link; Heim/Gast = die zwei Zellen
    # davor; Datum per Regex (der Header spannt "Tag Datum Zeit" über mehrere Datenspalten).
    def meeting_row(tr)
      link = tr.at_css('a[href*="groupMeetingReport"]')
      meeting_id = link && link["href"][/meeting=(\d+)/, 1]&.to_i
      return nil unless meeting_id

      tds = tr.css("td")
      result_cell = tds.find { |td| td.at_css('a[href*="groupMeetingReport"]') }
      idx = tds.index(result_cell)
      home = (idx && idx >= 2) ? tds[idx - 2] : nil
      guest = (idx && idx >= 1) ? tds[idx - 1] : nil
      date_cell = tds.find { |td| td.text =~ %r{\d{2}\.\d{2}\.\d{4}} }

      {
        meeting_id: meeting_id,
        date: date_cell&.text&.[](%r{\d{2}\.\d{2}\.\d{4}}),
        home_team: clean_text(home),
        guest_team: clean_text(guest),
        result: clean_text(result_cell)
      }
    end

    # Eine Rangliste-Zeile → Spieler oder nil (Header/ohne person-Link).
    def ranking_row(tr)
      link = tr.at_css('a[href*="person"]')
      person_id = link && link["href"][/person=(\d+)/, 1]&.to_i
      return nil unless person_id

      tds = tr.css("td")
      {person_id: person_id, name: clean_text(tds[1]), team_name: clean_text(tds[2])}
    end

    # Eigener Verein aus dem teamPortrait-Kopf: der ERSTE clubInfoDisplay-Link (Vereins-Zeile),
    # nicht die Gegner-Links aus der Spielplan-Tabelle darunter.
    def own_club(doc)
      link = doc.at_css('a[href*="clubInfoDisplay"]')
      return {club_id: nil, name: nil} unless link

      {club_id: link["href"][/club=(\d+)/, 1]&.to_i, name: clean_text(link)}
    end

    # Team-Name aus h1 (falls vorhanden) — sonst nil.
    def team_name(doc)
      h1 = doc.at_css("h1")
      h1 && clean_text(h1)
    end

    def clean_text(node)
      node&.text&.tr(" ", " ")&.gsub(/\s+/, " ")&.strip
    end

    # Standings-Tabelle (erste Tabelle): je Team-Zeile teamtable-ID + Name + data.
    # Spaltenlayout (aktuell, 11 td): 1 Rang · 2 Mannschaft · 3 Begegnungen · 4 S · 5 U · 6 N ·
    # 7 Partien · 8 +/- · 9 Spiele · 10 Punkte.
    def standings(doc)
      table = doc.css("table").first
      return [] unless table

      table.css("tr").filter_map do |tr|
        tds = tr.css("td")
        next if tds.empty?

        team_link = tr.at_css('a[href*="teamPortrait"]')
        teamtable_id = team_link && team_link["href"][/teamtable=(\d+)/, 1]&.to_i
        name = (team_link&.text || tds[2]&.text).to_s.strip
        next if name.empty?

        {
          teamtable_id: teamtable_id,
          name: name,
          rank: tds[1]&.text&.strip.to_i,
          data: {
            begegnungen: tds[3]&.text&.strip.to_i,
            wins: tds[4]&.text&.strip.to_i,
            draws: tds[5]&.text&.strip.to_i,
            losts: tds[6]&.text&.strip.to_i,
            partien: tds[7]&.text&.strip,
            diff: tds[8]&.text&.strip,
            spiele: tds[9]&.text&.strip,
            punkte: tds[10]&.text&.strip
          }
        }
      end
    end

    # Liga-/Staffel-Name aus h1 (Zeile 1 = championship, Zeile 2 = Staffelname).
    def group_name(doc)
      h1 = doc.at_css("h1")
      return nil unless h1

      lines = h1.text.split("\n").map(&:strip).reject(&:empty?)
      lines[1] || lines[0]
    end

    def championship(branch)
      Client.championship(federation: @federation, branch: branch, season_name: season_name)
    end

    def season_name
      @season.respond_to?(:name) ? @season.name : @season.to_s
    end
  end
end
