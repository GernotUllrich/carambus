# == Schema Information
#
# Table name: leagues
#
#  id                 :bigint           not null, primary key
#  ba_id2             :integer
#  name               :string
#  organizer_type     :string
#  registration_until :date
#  staffel_text       :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  ba_id              :integer
#  discipline_id      :integer
#  organizer_id       :integer
#  season_id          :integer
#
# Indexes
#
#  index_leagues_on_ba_id_and_ba_id2  (ba_id,ba_id2) UNIQUE
#
class League < ApplicationRecord
  has_many :league_teams
  has_many :parties
  has_many :tournaments
  belongs_to :organizer, polymorphic: true, optional: true
  belongs_to :discipline, optional: true
  belongs_to :season, optional: true

  DEBUG = true

  DEBUG_LOGGER = Logger.new("#{Rails.root}/log/debug.log")

  REFLECTION_KEYS = ["league_teams", "parties", "tournaments", "organizer", "discipline", "season"]
  COLUMN_NAMES = {
    "Name" => "leagues.name",
    "Organizer" => "organizer.shortname",
    "Season" => "season.name",
    "BA_ID" => "leagues.ba_id",
    "CC_ID" => "leagues.cc_id",
    "BA_ID2" => "leagues.ba_id2",
    "Discipline" => "discipline.name"
  }

  def name
    "#{read_attribute(:name)}#{" #{staffel_text}" if staffel_text.present?}"
  end

  def self.scrape_leagues_by_region_and_season(region, season)
    url = "https://#{region.shortname.downcase}.billardarea.de"
    uri = URI(url + '/cms_leagues')
    Rails.logger.info "reading #{url + '/cms_leagues'} - region #{region.shortname} league tournaments season #{season.name}"
    res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
    doc = Nokogiri::HTML(res.body)
    tabs = doc.css("#tabs li a")
    tabs.each_with_index do |tab, ix|
      dis_str = tab.text.strip()
      dis_str = "Carambol Match Billard" if dis_str == "Karambol großes Billard"
      dis_str = "Carambol Small Billard" if dis_str == "Karambol kleines Billard"
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

          url = "https://#{region.shortname.downcase}.billardarea.de"
          url_league = "/cms_leagues/plan/#{ba_id}"
          uri = URI(url + url_league)
          res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
          if res.code == "302"
            res2 = Net::HTTP.post_form(URI.parse(res['location']), 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
          else
            res2 = res
          end
          if res2.code == "200"
            doc = Nokogiri::HTML(res2.body)
            doc
          end
          ba_id2 = res['location'].match(/.*\/(\d+)\/(\d+)/).andand[2]
          staffel_map = { ba_id2 => "" }
          staffeln = doc.css('select[name="data[League][series_id]"]')
          if staffeln.present?
            options = staffeln.css("option")
            options.each do |option|
              staffel_map[option["value"].to_i] = option.text.strip
            end
          end
          staffel_map.each_pair do |ba_id2, text|
            args = {ba_id: ba_id, ba_id2: ba_id2, organizer: region, season: season, name: name, discipline: discipline}
            league = League.find_by_ba_id_and_ba_id2(ba_id, ba_id2) || League.new(args)
            league.assign_attributes(args)
            league.save
            league.scrape_single_league(game_details: true)
          end
        end
      end
    end
  end

  def scrape_single_league(opts = {})
    league_players = {}
    logger = opts[:logger] || Logger.new("#{Rails.root}/log/scrape.log")
    game_details = opts.keys.include?(:game_details) ? opts[:game_details] : true
    season = self.season
    organizer = self.organizer
    url = "https://#{organizer.shortname.downcase}.billardarea.de"
    url_league = "/cms_leagues/plan/#{self.ba_id}#{"/#{ba_id2}" if ba_id2.present?}"
    Rails.logger.info "reading #{url + url_league} - \"#{self.name}\" season #{season.name}"
    uri = URI(url + url_league)
    res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
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
        doc.css("#tabs li a").each_with_index do |tab, ix|
          next if ix == 0
          tab_tag = tab.attribute("href").value
          tab_text = tab.text.gsub("Spielplan ", "")
          doc.css("#{tab_tag} tr").each do |element|
            if element.css("td a").present?
              party_ba_id = element.css("td a").attribute("href").value.match(/.*\/(\d+)/)[1].to_i
              party = Party.find_by_ba_id(party_ba_id) || Party.create(ba_id: party_ba_id)
              tds = element.css("td")
              day_seqno = element.css("td")[0].text.to_i
              date = DateTime.parse("#{element.css("td")[1].text} #{element.css("td")[2].text}")
              team_a = league_teams.where(name: element.css("td")[3].text.strip()).first
              team_b = league_teams.where(name: element.css("td")[4].text.strip()).first
              host_team = league_teams.where(name: element.css("td")[6].text.strip()).first
              protest_link_html = element.css("td")[7]
              protest_link = Nokogiri::HTML(protest_link_html.inner_html).css("a").attribute("href").andand.value.to_s

              match_day_url = "/cms_leagues/matchday/#{party_ba_id}"
              uri = URI(url + match_day_url)
              res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
              player_a = player_b = game_name = nil
              res_hash = {}
              if res.code == "200"
                doc_party = Nokogiri::HTML(res.body)
                if protest_link.present?
                  winner_name_match = nil
                  winner_name = protest = remarks = ""
                  fields = doc_party.css("#tabs-3 label + .field")
                  if fields.present?
                    protest = fields[1].andand.text.andand.strip.to_s
                    winner_name_match = fields[0].text.strip.match(/(.*) gewinnt zu Null. Keine Spiele werden gespeichert/)
                    if winner_name_match.present?
                      winner_name = winner_name_match[1]
                    end
                  end
                  fields = doc_party.css("#tabs-2 label + .field")
                  remarks = fields.text.strip
                  if winner_name.present?
                    looser_team = team_a.name == winner_name ? team_b : team_a
                    party.assign_attributes(no_show_team_id: looser_team.id, remarks: { protest: protest, remarks: remarks })
                  end
                end
                party_data = { result: element.css("td")[5].text.strip() }
                party.assign_attributes(date: date, league: self, day_seqno: day_seqno, section: tab_text, league_team_a: team_a, league_team_b: team_b, host_league_team: host_team, data: party_data)
                party.save!

                trs = doc_party.css("tr + tr")
                ix = 0
                trs.each do |tr|
                  next if tr.text.blank?
                  tds = tr.css('td[width="100"]')
                  if tds.count == 1
                    ix = ix + 1
                    game_name = Nokogiri::HTML(tds[0].inner_html.gsub("<br>", "::")).css("b").inner_html.strip
                    tds_all = tr.css('td')
                    player_a = evaluate_league_players(tds_all[1].inner_html.gsub("<br>", "::").strip, league_players, team_a)
                    player_b = evaluate_league_players(tds_all[2].inner_html.gsub("<br>", "::").strip, league_players, team_b)

                  else
                    if game_name.match(/Snooker/).present?
                      tds_2 = tr.css('td').select do |td|
                        td.text.present?
                      end
                      res_hash = {
                        "Frames" => "#{tds_2[1].text.strip} : #{tds_2[5].andand.text.andand.strip.to_i}",
                        "HB" => "#{tds_2[3].text.strip} : #{tds_2[7].andand.text.andand.strip.to_i}",
                      }
                    else
                      tds_2 = tr.css('td')
                      column_count = tds_2.count / 2
                      res_hash = {}
                      (1..column_count).each_with_index do |_c2, ix2|
                        res_a = tds_2[0 + ix2].inner_html.gsub("<br>", " :: ").strip().gsub("\t", "").gsub(/\n+/, " :: ").squish.gsub(/::(?: ::)+/, "::").split(" :: ")
                        res_b = tds_2[column_count + ix2].inner_html.gsub("<br>", " :: ").strip().gsub("\t", "").gsub(/\n+/, " :: ").squish.gsub(/::(?: ::)+/, "::").split(" :: ")
                        res_hash[(res_a[-2] || "Ergebnis")] = "#{res_a[-1]} : #{res_b[-1]}"
                      end
                    end
                    party_game = PartyGame.find_by_seqno_and_party_id(ix, party.id) || PartyGame.create(seqno: ix, party: party)
                    party_game.update(player_a_id: player_a.id, player_b_id: player_b.id, data: { result: res_hash }, name: game_name)
                    party_game.update_discipline_from_name
                    party_game.save
                  end
                end
              end
            end
          end
        end
      end
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace.join("\n")}" if DEBUG
  end

  def self.logger
    DEBUG_LOGGER
  end

  private

  def evaluate_league_players(name_str, league_players, team)
    player = nil
    player_names = name_str.split("::")
    players = []
    player_names.each do |player_name_str|
      player_name = player_name_str.split(/\s+/)
      player_firstname = player_name[0..-2].join(" ")
      player_lastname = player_name[-1]
      player = league_players["#{player_firstname} #{player_lastname}"]
      if player.blank?
        player, seeding, state_ix = Player.fix_from_shortnames(player_lastname, player_firstname, season, organizer, team.club.shortname, nil, true)
        league_players["#{player_firstname} #{player_lastname}"] = player
      end
      players.push(player)
    end
    if players.count == 2
      player = Team.create(data: { "players" => [{ "firstname" => players[0].firstname,
                                                   "lastname" => players[0].lastname,
                                                   "ba_id" => players[0].ba_id,
                                                   "player_id" => players[0].id, },
                                                 { "firstname" => players[1].firstname,
                                                   "lastname" => players[1].lastname,
                                                   "ba_id" => players[1].ba_id,
                                                   "player_id" => players[1].id, }] })
    end
    return player
  end
end
