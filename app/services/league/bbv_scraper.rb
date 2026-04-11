# frozen_string_literal: true

# Kapselt die BBV-spezifische Scraping-Logik aus dem League-Modell.
# Verantwortlichkeiten:
#   - Eine einzelne BBV-Liga scrapen (Mannschaften und Ergebnisse)
#   - Alle BBV-Ligen einer Saison scrapen (Koordinations-Klassmethode)
#
# Verwendung:
#   League::BbvScraper.call(league: league, region: region)
#   League::BbvScraper.scrape_all(region: region, season: season)
#
# ApplicationService gemäß D-08/D-10 des Extraktionsplans.
class League::BbvScraper < ApplicationService
  BBV_BASE_URL = "https://bbv-billard.liga.nu"

  def initialize(kwargs = {})
    @league = kwargs[:league]
    @region = kwargs[:region]
    @opts = kwargs.except(:league, :region)
  end

  def call
    scrape_single_bbv_league
  end

  # Koordinationsmethode für alle BBV-Ligen einer Saison.
  # Gibt records_to_tag zurück (Array von Objekten für RegionTaggable).
  def self.scrape_all(region:, season:, opts: {})
    records_to_tag = []
    url = BBV_BASE_URL
    %w[Pool Snooker Karambol].each do |branch_str|
      branch = Branch.find_by_name(branch_str)
      leagues_url = "#{BBV_BASE_URL}/cgi-bin/WebObjects/nuLigaBILLARDDE.woa/wa/leaguePage?championship=BBV%20#{branch_str}%#{season.name.gsub("/20", "/")}"
      Rails.logger.info "reading #{leagues_url}"
      uri = URI(leagues_url)
      leagues_html = Net::HTTP.get(uri)
      leagues_html = leagues_html.dup.force_encoding("ISO-8859-1").encode("UTF-8")
      leagues_doc = Nokogiri::HTML(leagues_html)
      league_table = leagues_doc.css("table")[0]
      cols = league_table.css("td")
      cols.each do |td|
        _header = td.css("h2")[0].text
        td.css("a").each do |league_a|
          league_url = url + league_a.attributes["href"]
          league_shortname = league_a.text.strip
          league_doc, league_uri = fetch_league_doc(league_url)
          league_data = league_doc.css("h1")[0].inner_html.split("<br>").map(&:strip)
          name_arr = league_data[1].split(/\s+/)
          league_name = name_arr[0]
          staffel_text = name_arr[1..].join(" ")
          attrs = {organizer: region, staffel_text: staffel_text, name: league_name, season: season}.compact
          league = League.where(attrs).first || League.new(attrs)

          attrs = {shortname: league_shortname, discipline: branch}.compact
          league.assign_attributes(attrs)
          league.source_url = league_uri
          if league.changed?
            records_to_tag |= Array(league)
            league.save
          end
          records_to_tag |= Array(league.scrape_single_league_from_cc(opts.merge(league_doc: league_doc))) if opts[:league_details]
        end
      end
    end
    records_to_tag
  end

  # Hilfsmethode zum Laden eines Liga-Dokuments (auch von BbvScraper.scrape_all genutzt)
  def self.fetch_league_doc(league_url)
    Rails.logger.info "reading #{league_url}"
    league_uri = URI(league_url)
    league_html = Net::HTTP.get(league_uri)
      .gsub("//--", "--")
      .gsub('id="banner-groupPage-content"', "")
      .gsub('<meta name="uLigaStatsRefUrl"/>', "")
      .gsub("</meta>", "")
    league_doc = Nokogiri::HTML.fragment(league_html)
    [league_doc, league_uri]
  end

  private

  def scrape_single_bbv_league
    url = BBV_BASE_URL
    records_to_tag = []
    _logger = @opts[:logger] || Logger.new("#{Rails.root}/log/scrape.log")
    league_url = @league.source_url
    league_doc = @opts[:league_doc]
    league_doc, _league_uri = self.class.fetch_league_doc(league_url) unless league_doc.present?
    # scrape league teams with results
    records_to_tag |= Array(scrape_bbv_league_teams(league_doc, league_url, url))
    nav_link = league_doc.css("#sub-navigation a").find { |a| a.text =~ /Spielplan \(Gesamt\)/ }
    _parties_table_url = nav_link ? url + nav_link.attributes["href"].value : nil

    [league_url, records_to_tag]
  end

  # scrape bbv league teams with results
  def scrape_bbv_league_teams(league_doc, league_url, url)
    records_to_tag = []
    team_table_doc = league_doc
    html = team_table_doc.css("table")[0]
    _headers = html.css("th").map(&:text)
    html.css("tr").each do |tr|
      next if tr.css("td").count == 0

      args = tr.css("td").map(&:inner_html)
      _rang = args[1].to_i
      if tr.css("td")[2].css("a")[0].present?
        team_url = url + tr.css("td")[2].css("a")[0].andand.attributes.andand["href"]
        Rails.logger.info "reading #{team_url}"
        team_uri = URI(team_url)
        team_html = Net::HTTP.get(team_uri)
          .gsub("//--", "--")
          .gsub('id="banner-groupPage-content"', "")
          .gsub(/<meta name="uLigaStatsRefUrl"\s*\/>/, "")
          .gsub("</meta>", "")
        team_doc = Nokogiri::HTML.fragment(team_html)
        club_url = url + team_doc.css("#content-row1 a:nth-child(1)")[0].attributes["href"]
        club_cc_id = club_url.match(/club=(\d+)/)[1].to_i
        club = Club.where(region: @league.organizer, cc_id: club_cc_id).first
        team_name = tr.css("td")[2].css("a")[0].text.strip
        team_cc_id = team_url.match(/teamtable=(\d+)/)[1]
      else
        team_name = tr.css("td")[2].text.strip
        club = Club.where(region: @league.organizer).where("clubs.name ilike '%#{team_name.gsub(/ [IV]+$/, "")}%'").first
        Rails.logger.info "===== scrape ===== scrape leagues - cannot match club from Teamname #{team_name}, league: #{@league.name} #{@league.staffel_text}"
      end
      parties = args[3].to_i
      wins = args[4].to_i
      draws = args[5].to_i
      losts = args[6].to_i
      result = args[7].strip
      diff = args[8].strip
      points = args[9].strip
      data = {
        parties: parties,
        wins: wins,
        draws: draws,
        losts: losts,
        result: result,
        diff: diff,
        points: points
      }
      league_team = @league.league_teams.where(cc_id: team_cc_id).first
      league_team ||= @league.league_teams.new(cc_id: team_cc_id)
      attrs = {
        name: team_name,
        club_id: club&.id,
        data: data
      }
      league_team.assign_attributes(attrs)
      league_team.source_url = league_url
      if league_team.changed?
        records_to_tag |= Array(league_team)
        league_team.save
      end
    end
    records_to_tag
  end
end
