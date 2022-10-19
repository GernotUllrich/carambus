# == Schema Information
#
# Table name: leagues
#
#  id                 :bigint           not null, primary key
#  ba_id2             :integer
#  name               :string
#  organizer_type     :string
#  registration_until :date
#  shortname          :string
#  staffel_text       :string
#  type               :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  ba_id              :integer
#  cc_id              :integer
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
  #belongs_to :region, -> { where(leagues: { organizer_type: "Region" }) }, foreign_key: "organizer_id"

  belongs_to :discipline, optional: true
  belongs_to :season, optional: true
  has_one :league_cc, -> { where(context: 'nbv') }

  DEBUG = true

  DEBUG_LOGGER = Logger.new("#{Rails.root}/log/debug.log")

  REFLECTION_KEYS = ["league_teams",
                     "parties",
                     "tournaments",
                     "organizer",
                     "region",
                     "discipline",
                     "season",
                     "league_cc"]
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

  def branch
    branch = discipline
    while branch.andand.super_discipline.present?
      branch = branch.super_discipline
    end
    branch

  end

  def competition
    Competition.where(super_discipline_id: discipline_id).where("name ilike '%Mannschaft%'").first
  end

  def self.scrape_leagues_by_region_and_season(region, season, opts = {})
    url_top = "https://#{region.shortname.downcase}.billardarea.de"
    uri_top = URI(url_top + '/cms_leagues')
    Rails.logger.info "reading #{url_top + '/cms_leagues'} - region #{region.shortname} league tournaments season #{season.name}"
    res_top = Net::HTTP.post_form(uri_top, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
    doc_top = Nokogiri::HTML(res_top.body)
    tabs = doc_top.css("#tabs li a")
    tabs.each_with_index do |tab, ix|
      dis_str = tab.text.strip()
      #dis_str = "Carambol Match Billard" if dis_str == "Karambol großes Billard"
      #dis_str = "Carambol Small Billard" if dis_str == "Karambol kleines Billard"
      discipline = Discipline.find_by_name(dis_str)
      tab = "#tabs-#{ix + 1} a"
      lines = doc_top.css(tab)
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
            if res['location'] == (url + url_league + "/")
              Rails.logger.error "====== cannot read from #{url_league} - loop"
              next
            end
            res2 = Net::HTTP.post_form(URI.parse(res['location']), 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
          else
            res2 = res
          end
          if res2.code == "200"
            doc = Nokogiri::HTML(res2.body)
            doc
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
            args = { ba_id: ba_id, ba_id2: ba_id2, organizer: region, season: season, name: name, discipline: discipline }
            league = League.find_by_ba_id_and_ba_id2(ba_id, ba_id2) || League.new(args)
            league.assign_attributes(args)
            league.save
              league.scrape_single_league(opts)
            end
          else
            Rails.logger.error "====== cannot read from #{url_league}"
          end
        end
      end
    end
  end

  def scrape_single_league(opts = {})
    return if opts[:skip_league_details]
    league_players = {}
    logger = opts[:logger] || Logger.new("#{Rails.root}/log/scrape.log")
    game_details = opts.keys.include?(:game_details) ? opts[:game_details] : true
    season = self.season
    organizer = self.organizer
    url = "https://#{organizer.shortname.downcase}.billardarea.de"
    url_league = "/cms_leagues/plan/#{self.ba_id}#{"/#{ba_id2}" if ba_id2.present?}"
    League.set_scraping(1, url_league == "/cms_leagues/plan/4112/5692")
    return unless League.scraping[0] && League.scraping[1]
    Rails.logger.info "reading #{url + url_league} - \"#{self.name}\" season #{season.name}"
    uri = URI(url + url_league)
    res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")

    if res.code == "302"
      self.ba_id2 = res['location'].match(/.*\/(\d+)\/(\d+)/).andand[2].to_i
      res2 = Net::HTTP.post_form(URI.parse(res['location']), 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
    else
      res2 = res
    end
    if res2.code == "200"
      doc = Nokogiri::HTML(res2.body)
      staffel_map = {}
      staffeln = doc.css('select[name="data[League][series_id]"]')
      if staffeln.present?
        options = staffeln.css("option")
        options.each do |option|
          staffel_map[option["value"].to_i] = option.text.strip
        end
      end
      self.staffel_text = staffel_map[self.ba_id2]
      self.save!
      league_teams_found = []
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
        league_teams_found.push(league_team)
      end
      league_teams_found.each do |league_team|
        url_lt = "https://#{organizer.shortname.downcase}.billardarea.de/cms_teams/show/#{league_team.ba_id}"
        Rails.logger.info "reading index page league_team #{league_team.name} (#{league_team.ba_id}) to scrape league"
        html_lt = URI.open(url_lt)
        doc_lt = Nokogiri::HTML(html_lt)
        tables = doc_lt.css("table.matchday_table")
        links = tables[0].css("a")
        links.map do |d|
          [d["href"], d.text]
        end.each do |arr|
          url_player, name_str = arr
          club_ba_id, player_ba_id = url_player.match(/.*\/(\d+)\/(\d+)$/).andand[1..2].andand.map(&:to_i)
          club = Club.find_by_ba_id(club_ba_id) # TODO find corresp. Club or create
          html_player = URI.open(url + url_player)
          doc_player = Nokogiri::HTML(html_player)
          elements = doc_player.css(".element")
          player_ba_id = nil
          firstname = lastname = nil
          elements.each do |element|
            if element.css("> label").text == "Spielernummer"
              player_ba_id = element.css(".field").text.to_i
            elsif element.css("> label").text == "Name"
              lastname, firstname = element.css(".field").text.split(", ").map(&:strip).map(&:to_s)
            end
            args = {}
            if player_ba_id.present? && lastname.present?
              player = Player.find_by_ba_id(player_ba_id)
              player ||= Player.where(type: nil, firstname: firstname, lastname: lastname, club_id: club.andand.id).where("ba_id > 900000000").first
              player ||= Player.where(type: nil, firstname: firstname, lastname: lastname).where("ba_id > 900000000").first
              if player.present?
                player.andand.update(ba_id: player_ba_id)
              end
              break
            end
          end
        end

      end
      if game_details
        doc.css("#tabs li a").each_with_index do |tab, ixt|
          next if ixt == 0
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
                      winner_name = winner_name_match[1].strip
                    end
                  end
                  fields = doc_party.css("#tabs-2 label + .field")
                  remarks = fields.text.strip
                  if winner_name.present?
                    looser_team = team_a.name == winner_name ? team_b : team_a
                    party.assign_attributes(party.attributes.merge(no_show_team_id: looser_team.id, remarks: { protest: protest, remarks: remarks }))
                  else
                    party.assign_attributes(party.attributes.merge(remarks: { protest: protest, remarks: remarks }))
                  end
                end
                party_data = { result: element.css("td")[5].text.strip() }
                round = "1"
                round = "2" if tab_text == "Rückrunde"
                party.assign_attributes(party.attributes.merge(date: date, league: self, day_seqno: day_seqno, section: tab_text, round: round, league_team_a: team_a, league_team_b: team_b, host_league_team: host_team, data: party_data))
                party.save!

                trs = doc_party.css("tr + tr")
                ix = 0
                game_count = 0
                trs.each do |tr|
                  next if tr.text.blank?
                  tds = tr.css('td[width="100"]')
                  if tds.count == 1
                    game_count = 1
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
                      if game_count > 0
                        tds_2 = tr.css('td')
                        column_count = tds_2.count / 2
                        res_hash = {}
                        (1..column_count).each_with_index do |_c2, ix2|
                          res_a = tds_2[0 + ix2].inner_html.gsub("<br>", " :: ").strip().gsub("\t", "").gsub(/\n+/, " :: ").squish.gsub(/::(?: ::)+/, "::").split(" :: ")
                          res_b = tds_2[column_count + ix2].inner_html.gsub("<br>", " :: ").strip().gsub("\t", "").gsub(/\n+/, " :: ").squish.gsub(/::(?: ::)+/, "::").split(" :: ")
                          res_hash[(res_a[-2] || "Ergebnis")] = "#{res_a[-1]} : #{res_b[-1]}"
                        end
                        game_count = game_count - 1
                      else
                        next
                      end
                    end
                    party_game = PartyGame.find_by_seqno_and_party_id(ix, party.id) || PartyGame.create(seqno: ix, party: party)
                    party_game.update(player_a_id: player_a.andand.id, player_b_id: player_b.andand.id, data: { result: res_hash }, name: game_name)
                    party_game.update_discipline_from_name
                    party_game.save
                  end
                end
              end
            end
          end
        end
      end
      self.fix_seqnos if opts[:fix_seqnos]
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace.join("\n")}" if DEBUG
  end

  @@scraping = []

  def self.scraping
    @@scraping
  end

  def self.set_scraping(ix, val)
    if val && @@scraping[ix].blank?
      Rails.logger.info "========== start scraping #{ix}"
      @@scraping[ix]  ||= val
    end
  end

  def fix_seqnos
    seqno = 0
    date = nil
    parties.order(:date, :id).each do |party|
      if party.date != date
        seqno = seqno + 1
        date = party.date
      end
      party.update(day_seqno: seqno)
    end
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
      words_firstname = player_name[0..-2]
      words_lastname = Array(player_name[-1])
      player = nil
      while words_firstname.count > 0
        player_firstname = words_firstname.join(" ")
        player_lastname = words_lastname.join(" ")
        player = league_players["#{player_firstname} #{player_lastname}"]
        if player.blank?
          player, seeding, state_ix = Player.fix_from_shortnames(player_lastname, player_firstname, season, organizer, team.andand.club.andand.shortname.to_s, nil, true, false)
          league_players["#{player_firstname} #{player_lastname}"] = player
        end
        if player.present?
          players.push(player)
          break
        else
          take_last_word_from_firstname = words_firstname.pop
          words_lastname.unshift(take_last_word_from_firstname)
        end
      end
      if player.blank?
        player_name = player_name_str.split(/\s+/)
        words_firstname = player_name[0..-2]
        words_lastname = Array(player_name[-1])
        player_firstname = words_firstname.join(" ")
        player_lastname = words_lastname.join(" ")
        player = league_players["#{player_firstname} #{player_lastname}"]
        if player.blank?
          player, seeding, state_ix = Player.fix_from_shortnames(player_lastname, player_firstname, season, organizer, team.andand.club.andand.shortname.to_s, nil, true, true)
          league_players["#{player_firstname} #{player_lastname}"] = player
          if player.present?
            players.push(player)
          end
        end
      end
    end
    if players.count == 2
      args = { data: { "players" => [{ "firstname" => players[0].firstname,
                                       "lastname" => players[0].lastname,
                                       "ba_id" => players[0].ba_id,
                                       "player_id" => players[0].id, },
                                     { "firstname" => players[1].firstname,
                                       "lastname" => players[1].lastname,
                                       "ba_id" => players[1].ba_id,
                                       "player_id" => players[1].id, }] } }

      player = Team.where(args).first || Team.create(args)
    end
    return player
  end
end
