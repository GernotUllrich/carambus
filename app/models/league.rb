# == Schema Information
#
# Table name: leagues
#
#  id                 :bigint           not null, primary key
#  ba_id2             :integer
#  name               :string
#  organizer_type     :string
#  registration_until :date
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  ba_id              :integer
#  discipline_id      :integer
#  organizer_id       :integer
#  season_id          :integer
#
class League < ApplicationRecord
  has_many :league_teams
  has_many :parties
  has_many :tournaments
  belongs_to :organizer, polymorphic: true, optional: true
  belongs_to :discipline, optional: true
  belongs_to :season, optional: true

  DEBUG_LOGGER = Logger.new("#{Rails.root}/log/debug.log")

  def self.scrape_leagues_by_region_and_season(region, season)
    url = "https://#{region.shortname.downcase}.billardarea.de"
    uri = URI(url + '/cms_leagues')
    Rails.logger.info "reading #{url + '/cms_leagues'} - region #{region.shortname} league tournaments season #{season.name}"
    res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
    doc = Nokogiri::HTML(res.body)
    tabs = doc.css("#tabs a")
    tabs.each_with_index do |tab, ix|
      dis_str = tab.text.strip()
      discipline = Discipline.find_by_name(dis_str)
      tab = "#tabs-#{ix + 1} a"
      lines = doc.css(tab)
      lines.each do |line|
        name = line.text.strip
        url = line.attribute("href").value
        m = url.match(/\/cms_(single|leagues)\/(plan|show)\/(\d+)$/)
        ba_id = m[3] rescue nil
        single_or_league = m[1] rescue nil
        plan_or_show = m[2] rescue nil
        if ba_id.present?
          league = League.find_by_ba_id(ba_id) || League.create(ba_id: ba_id, organizer: region, season: season)
          league.update(name: name, discipline: discipline)
          league.scrape_single_league(game_details: true)
        end
      end
    end
  end

  def scrape_single_league(opts = {})
    self.reset_league
    league_players = {}
    logger = opts[:logger] || Logger.new("#{Rails.root}/log/scrape.log")
    game_details = opts.keys.include?(:game_details) ? opts[:game_details] : true
    season = self.season
    organizer = self.organizer
    url = "https://#{organizer.shortname.downcase}.billardarea.de"
    url_league = "/cms_leagues/plan/#{self.ba_id}"
    Rails.logger.info "reading #{url + url_league} - self \"#{self.name}\" season #{season.name}"
    uri = URI(url + url_league)
    res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
    ba_id2 = res['location'].match(/.*\/(\d+)\/(\d+)/).andand[2]
    if res.code == "302"
      res2 = Net::HTTP.post_form(URI.parse(res['location']), 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
    else
      res2 = res
    end
    if res2.code == "200"
      doc = Nokogiri::HTML(res2.body)
      doc.css("#table-1 a").each do |element|
        league_team_ba_id = element.attributes["href"].value.match(/.*\/(\d+)/)[1].to_i
        shortname = element.text.strip()
        club_shortname = shortname
        mm = shortname.match(/(.*)(?:\s+(\d+))/)
        if mm && mm[2]
          club_shortname = mm[1].strip
        end
        league_team = LeagueTeam.find_by_ba_id(league_team_ba_id)
        league_team ||= LeagueTeam.create(ba_id: league_team_ba_id)
        club = Club.find_by_shortname(club_shortname)
        unless club.present?
          region = organizer.is_a?(Region) ? organizer : nil
          logger.info "[scrape_tournaments] Inkonsistence - fatal: Club #{club_shortname}, region #{region.andand.shortname} not found!! Typo?"
          if region.present?
            fixed_club = region.clubs.create(name: club_shortname, shortname: club_shortname)
          else
            fixed_club = Club.create(name: club_shortname, shortname: club_shortname)
          end
          fixed_club.update(ba_id: 999000000 + fixed_club.id)
          club = fixed_club
        end

        league_team.update(name: shortname, club: club, league: self)
        league_team
      end
      if game_details
        doc.css("#tabs-2 tr").each do |element|
          if element.css("td a").present?
            party_ba_id = element.css("td a").attribute("href").value.match(/.*\/(\d+)/)[1].to_i
            party = Party.find_by_ba_id(party_ba_id) || Party.create(ba_id: party_ba_id)
            tds = element.css("td")
            day_seqno = element.css("td")[0].text.to_i
            date = DateTime.parse("#{element.css("td")[1].text} #{element.css("td")[2].text}")
            team_a = league_teams.where(name: element.css("td")[3].text.strip()).first
            team_b = league_teams.where(name: element.css("td")[4].text.strip()).first
            host_team = league_teams.where(name: element.css("td")[6].text.strip()).first
            party_data = { result: element.css("td")[5].text.strip() }
            party.update(date: date, league: self, day_seqno: day_seqno, league_team_a: team_a, league_team_b: team_b, host_league_team: host_team, data: party_data)
            party.save!
            match_day_url = "/cms_leagues/matchday/#{party_ba_id}"
            uri = URI(url + match_day_url)
            res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
            if res.code == "200"
              doc_party = Nokogiri::HTML(res.body)
              result = doc_party.css("#tabs-1 div b").first.text.gsub(/\n+/, "::").squish.gsub(":: ::", "::").split(" :: ")
              tbl = doc_party.css("table.score_table").first
              rows = tbl.css("tr")[2..-2]
              (1..rows.count / 3).each_with_index do |_c, ix|
                doc_game = Nokogiri::HTML(rows[ix * 3].inner_html.gsub("<br>", "::"))
                doc_game2 = Nokogiri::HTML(rows[ix * 3 + 1].inner_html)
                tds_2 = doc_game2.css("td")
                column_count = tds_2.count / 2
                res_hash = {}
                (1..column_count).each_with_index do |_c2, ix2|
                  res_a = tds_2[0 + ix2].text.strip().gsub("\t", "").gsub(/\n+/, "::").squish.gsub(":: ::", "::").split(" :: ")
                  res_b = tds_2[column_count + ix2].text.strip().gsub("\t", "").gsub(/\n+/, "::").squish.gsub(":: ::", "::").split(" :: ")
                  res_hash[(res_a[-2] || "Ergebnis")] = "#{res_a[-1]} : #{res_b[-1]}"
                end
                tds = doc_game.css("td")
                game_name = tds[0].text.strip
                player_a = evaluate_league_players(tds[1].text, league_players, team_a, ix)
                player_b = evaluate_league_players(tds[2].text, league_players, team_b, ix)
                party_game = PartyGame.find_by_seqno_and_party_id(ix + 1, party.id) || PartyGame.create(seqno: ix + 1, party: party)
                party_game.update(player_a_id: player_a.id, player_b_id: player_b.id, data: { result: res_hash }, name: game_name)
              end
            end
          end
        end
      end
    end
  end

  def reset_league
  end

  def self.logger
    DEBUG_LOGGER
  end

  private

  def evaluate_league_players(name_str, league_players, team, ix)
    player = nil
    player_names = name_str.split("::")
    player_names[0..0].each do |player_name_str|
      player_name = player_name_str.split(/\s+/)
      player_firstname = player_name[0..-2].join(" ")
      player_lastname = player_name[-1]
      player = league_players["#{player_firstname} #{player_lastname}"]
      if player.blank?
        player, seeding, state_ix = Player.fix_from_shortnames(player_lastname, player_firstname, season, organizer, team.club.shortname, nil, true)
        league_players["#{player_firstname} #{player_lastname}"] = player
      end
    end
    return player
  end
end
