# encoding: utf-8
require "#{Rails.root}/app/helpers/application_helper"
require 'open-uri'
require 'uri'
require 'net/http'
require 'csv'

DE_DISCIPLINE_NAMES = ["Pool", "Snooker", "Kegel", "5 Kegel", "Karambol großes Billard", "Karambol kleines Billard", "Biathlon"]
DISCIPLINE_NAMES = ["Pool", "Snooker", "Pin Billards", "5-Pin Billards", "Carambol Match Billard", "Carambol Small Billard", "Biathlon"]

include ApplicationHelper

namespace :carambus do

  desc "eliminate location duplicates"
  task :eliminate_location_duplicates => :environment do

  end

  desc "read regional player ids"
  task :read_regional_player_ids => :environment do
    players = CSV.parse(File.read("#{Rails.root}/doc/20220302_Stammdaten-NBV-MITGLIEDER.csv"), headers: false)
    players.each do |player_str|
      player_arr = player_str[0].split(";")
      player_arr
      player = Player.find_by_ba_id(player_arr[0])
      player.andand.update(cc_id: player_arr[1])
      player
    end
  end

  desc "update disciplines in party games"
  task :update_disciplines_in_party_games => :environment do
    PartyGame.all.each do |pg|
      pg.update_discipline_from_name
      pg.save
    end
  end

  desc "Scrape leagues"
  task :scrape_leagues => :environment do
    Season.order(ba_id: :desc).limit(2).each do |season|
      Region.all.each do |region|
        League.scrape_leagues_by_region_and_season(region, season)
      end
    end
  end

  desc "Scrape DBU leagues"
  task :scrape_dbu_leagues => :environment do
    Season.order(ba_id: :desc).limit(2).each do |season|
      League.scrape_leagues_by_region_and_season(Region.find_by_shortname("portal"), season)
    end
  end

  desc "scrape regional club ids"
  task :scrape_regional_club_ids => :environment do
    url = "https://ndbv.club-cloud.de/verein-details.php?p=20-----1-100000-0"
    Rails.logger.info "reading index page - to scrape regional club ids"
    html = URI.open(url)
    doc = Nokogiri::HTML(html)
    clubs = doc.css("article .cc_bluelink")
    clubs.each do |club|
      url = club.attribute("href").value
      params = url.match(/.*p=(.*)/).andand[1].split(/-\|/)
      params
      club_title = club.text
      c = Club.where(region_id: 1, shortname: club_title).first
      c.update(cc_id: params[3].to_i) if c.present?
    end
  end

  desc "create countries"
  task :create_countries => :environment do
    Country.initdb
  end

  desc "scrape regions"
  task :scrape_regions => :environment do
    Region.scrape_regions
    country_de = Country.find_by_code("DE")
    url = "https://portal.billardarea.de"
    Rails.logger.info "reading index page - to scrape regions"
    html = open(url)
    doc = Nokogiri::HTML(html)
    regions = doc.css(".img_bw")
    regions.each do |region|
      region_name = region.attribute("alt").value
      region_shortname = region.attribute("name").value
      region_logo = url + region.attribute("onmouseover").value.gsub(/MM_swapImage\('#{region_shortname}','','(.*)',1\).*/, '\1')
      r = Region.find_by_shortname(region_shortname) || Region.new
      r.update(name: region_name, shortname: region_shortname, logo: region_logo, country: country_de)
    end
  end

  desc "list of scaffolds"
  task "list_scaffolds" => :environment do
    arr = Module.constants.select do |constant_name|
      constant = eval constant_name.to_s
      if not constant.nil? and constant.is_a? Class and constant.superclass == ActiveRecord::Base
        constant
      end
    end
    puts arr.inspect
  end

  desc "Update Seasons"
  task :update_seasons => :environment do
    Season.update_seasons
  end

  desc "daily update"
  task :daily_update => :environment do
    if Season.find_by_name("#{Date.today.year}/#{Date.today.year + 1}").blank?
      Season.update_seasons
    end
    Region.scrape_regions
  end

  desc "scrape clubs"
  task :scrape_clubs => :environment do
    Club.scrape_clubs(player_details: true)
  end

  desc "scrape Players"
  task :scrape_players => :environment do
    ids = []
    fname = "#{Rails.root}/tmp/pids/XXX"
    if File.exist?(fname)
      ids = File.read(fname).split(/\s/)
    end
    done_ids = ids
    Player.includes(:club => :region).where.not(id: ids).each do |player|
      done_ids << player.id.to_s
      write_ids(fname, done_ids) if (done_ids.count % 1000 == 0)
      club = player.club
      url = "https://#{player.club.region.shortname.downcase}.billardarea.de"
      player_details_url = "#{url}/cms_clubs/playerdetails/#{club.ba_id}/#{player.ba_id}"
      Rails.logger.info "reading #{player_details_url} - player details of player [#{player.ba_id}] on club #{club.shortname} [#{club.ba_id}]"
      html_player_detail = Uri.open(player_details_url)
      doc_player_detail = Nokogiri::HTML(html_player_detail)
      player_ba_id = doc_player_detail.css("#tabs-1 fieldset:nth-child(1) legend+ .element .field").text.strip.to_i
      if player_ba_id == player.ba_id
        player_title = doc_player_detail.css("#tabs-1 fieldset:nth-child(1) .element:nth-child(3) .field").text.strip
        player_lastname, player_firstname = doc_player_detail.css("#tabs-1 fieldset:nth-child(1) .element:nth-child(4) .field").text.strip.split(", ")
        player.update(title: player_title, lastname: player_lastname, firstname: player_firstname)
      end
    end
    write_ids(fname, done_ids)
  end

  def write_ids(fname, done_ids)
    f = File.new(fname, "w")
    f.write(done_ids.map(&:to_s).join(" "))
    f.close
  end

  desc "retrieve updates from API server"
  task :retrieve_updates => :environment do
    Version.update_from_carambus_api
  end

  desc "Init Disciplines"
  task :init_disciplines => :environment do

    TABLE_KINDS = ["Pool", "Snooker", "Small Billard", "Half Match Billard", "Match Billard"]

    TABLE_KIND_DISCIPLINE_NAMES = {
      "Pin Billards" => [],
      "Biathlon" => [],
      "5-Pin Billards" => [],
      "Pool" => ["9-Ball", "8-Ball", "14.1 endlos", "Blackball"],
      "Small Billard" => ["Dreiband klein", "Freie Partie klein", "Einband klein", "Cadre 52/2", "Cadre 35/2", "Biathlon", "Nordcup", "Petit/Grand Prix"],
      "Match Billard" => ["Dreiband groß", "Einband groß", "Freie Partie groß", "Cadre 71/2", "Cadre 47/2", "Cadre 47/1"],
      "Half Match Billard" => ["Cadre 38/2", "Cadre 57/2"] }

    TABLE_KIND_DISCIPLINE_NAMES.each do |tk_name, v|
      tk = TableKind.find_by_name(tk_name) ||
        TableKind.create(name: tk_name)
      v.each do |dis_name|
        Discipline.find_by_name_and_table_kind_id(dis_name, tk.id) ||
          Discipline.create(name: dis_name, table_kind_id: tk.id)
      end
    end
  end

  desc "update disciplines in party games"
  task :update_disciplines_in_party_games => :environment do
    PartyGame.all.each do |pg|
      pg.update_discipline_from_name
      pg.save
    end
  end

  desc "Scrape leagues"
  task :scrape_leagues => :environment do
    Season.order(ba_id: :desc).limit(2).each do |season|
      Region.all.each do |region|
        League.scrape_leagues_by_region_and_season(region, season)
      end
    end
  end

  desc "Scrape DBU leagues"
  task :scrape_dbu_leagues => :environment do
    Season.order(ba_id: :desc).limit(2).each do |season|
      League.scrape_leagues_by_region_and_season(Region.find_by_shortname("portal"), season)
    end
  end

  desc "Scrape leagues"
  task :scrape_leagues_alternative => :environment do #TODO still necessary?
    debug = false #true
    Season.order(ba_id: :desc).limit(2).each do |season|
      (next unless season.id == 13) if debug
      Region.all.each do |region|
        (next unless region.shortname == "NBV") if debug
        url = "https://#{region.shortname.downcase}.billardarea.de"
        uri = URI(url + '/cms_leagues')
        Rails.logger.info "reading #{url + '/cms_leagues'} - region #{region.shortname} league tournaments season #{season.name}"
        res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
        doc = Nokogiri::HTML(res.body)
        tabs = doc.css("#tabs a")
        tabs.each_with_index do |tab, ix|
          tab_text = tab.text.strip
          if Discipline::DE_DISCIPLINE_NAMES.include?(tab_text)
            discipline_name = Discipline::DISCIPLINE_NAMES[Discipline::DE_DISCIPLINE_NAMES.index(tab_text)]
            discipline = Discipline.find_by_name(discipline_name)
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
                league = League.find_by_ba_id(ba_id) || League.create(ba_id: ba_id, discipline_id: discipline.andand.id, organizer: region, season: season)
                league.update(name: name)
                league.scrape_single_league(game_details: true)
              end
            end
          else
            break
          end
        end
      end
    end
  end

  desc "fix tournament discipline by name"
  task :fix_tournament_discipline_by_name => :environment do
    unknown_discipline = Discipline.find_by_name("-")
    Tournament.where(discipline_id: unknown_discipline.id).all.each do |tournament|
      Tournament::NAME_DISCIPLINE_MAPPINGS.each do |k, v|
        if tournament.title =~ /#{k}/
          tournament.update(discipline_id: Discipline.find_by_name(v).id)
        end
      end
    end
  end

  desc "update tournament_plan executor_params"
  # TODO TournamentPlans should be generated from readable Version in TournamentPlan Model
  task :update_executor_params => :environment do
    TournamentPlan.update_executor_params
  end

  desc "Scrape Tournaments"
  task :scrape_tournaments => :environment do

    Season.order(name: :desc).to_a[0..1].each do |season|
      season.scrape_tournaments
    end
  end

  desc "Scrape League Teams"
  task :scrape_league_teams => :environment do

    Season.order(name: :asc).each do |season|
      Region.all.each do |region|
        #next unless region.shortname == "NBV"
        url = "https://#{region.shortname.downcase}.billardarea.de"
        uri = URI(url + '/cms_leagues')
        Rails.logger.info "reading #{url + '/cms_leagues'} - region #{region.shortname} leagues in season #{season.name}"
        res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
        doc = Nokogiri::HTML(res.body)

        tabs = doc.css("#tabs > ul > li > a")
        tabs.each_with_index do |tab, ix|
          tab_text = tab.text.strip
          if Discipline::DE_DISCIPLINE_NAMES.include?(tab_text)
            discipline_name = Discipline::DISCIPLINE_NAMES[Discipline::DE_DISCIPLINE_NAMES.index(tab_text)]
            discipline = Discipline.find_by_name(discipline_name)
            tab = "#tabs-#{ix + 1} a"
            lines = doc.css(tab)
            lines.each do |line|
              name = line.text.strip
              url2 = line.attribute("href").value
              m = url2.match(/\/cms_(single|leagues)\/(plan|show)\/(\d+)$/)
              ba_id = m[3] rescue nil
              single_or_league = m[1] rescue nil
              plan_or_show = m[2] rescue nil
              if ba_id.present?
                uri_league = URI(url + url2)
                res2 = Net::HTTP.post_form(uri_league, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
                if res2.code == "302"
                  ba_id2 = res2['location'].match(/.*\/(\d+)\/(\d+)/).andand[2].to_i
                  res3 = Net::HTTP.post_form(URI.parse(res2['location']), 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
                else
                  res3 = res
                end
                if res3.code == "200"
                  doc = Nokogiri::HTML(res3.body)
                  doc.css('#tabs-1 table > tr > td > a').each do |team|
                    url_team = team["href"]
                    team_name = team.text.strip
                    uri_team = URI(url + url_team)
                    res_team = Net::HTTP.post_form(uri_team, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
                    doc_team = Nokogiri::HTML(res_team.body)
                    doc_team
                    doc_team.css("table.matchday_table").each do |table|
                      ths = table.css("> tr > th")
                      if ths.present? && ths[0].text == "Name"
                        table.css("> tr > td > a").each do |player_css|
                          url_player = player_css["href"]
                          club_ba_id = url_player.match(/.*\/(\d+)\/(\d+)$/).andand[1].to_i
                          club = Club.find_by_ba_id(club_ba_id)
                          unless club.present?
                            Rails.logger.info "REPORT! [scrape_league_teams] Unknown Club #{}"
                          end
                          player_name = player_css.text.strip
                          uri_player = URI(url + url_player)
                          ba_id_player = url_player.match(/.*\/(\d+)$/).andand[1].andand.to_i
                          player = Player.find_by_ba_id(ba_id_player)
                          if player.present? && club.present?
                            player.assign_attributes(club_id: club.id)
                            if player.club_id_changed?
                              player.save!
                              Rails.logger.info "REPORT! [scrape_league_teams] Player[#{player.id}] #{player.fullname} changed to Club #{club.name}: #{player.changes.inspect}"
                            end
                          end
                          res_player = Net::HTTP.post_form(uri_player, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
                          doc_player = Nokogiri::HTML(res_player.body)
                          doc_player
                          elements = doc_player.css("#tabs-1 > fieldset > .element")
                          name_str = elements[2].css("> .field").text.strip
                          lastname, firstname = name_str.split(", ")
                          player = region.fix_player_without_ba_id(firstname, lastname, ba_id_player, club.andand.id)
                        end
                      end
                    end
                  end
                end
              else
                ba_id
              end
            end
          else
            break
          end
        end
      end
    end
  end

  desc "Init PlayerClass"
  task :init_player_classes => :environment do

  end
  desc "Scrape Tournament Details"
  task :scrape_tournaments_details => :environment do
    logger = Logger.new("#{Rails.root}/log/scrape.log")
    on = false
    Season.where("ba_id > #{Season.find_by_name("2011/2012").id}").order(ba_id: :desc).each do |season|
      Region.all.each do |region|
        #next unless region.shortname == "NBV" #TODO TEST
        season.tournaments.joins(:region).
          #where(ba_id: 13933).#TODO TEST
          where(region_id: region.id).all.each do |tournament|
          on = on || tournament.ba_id == 12421
          if on
            scrape_single_tournament(tournament, logger: logger)
            tournament.update_columns(last_ba_sync_date: Time.now)
          end
        end
      end
    end
  end

  desc "remove duplicate season participations"
  task :remove_duplicate_season_participations => :environment do
    grouped = SeasonParticipation.all.group_by { |s| [s.player_id, s.club_id, s.season_id] }
    grouped.values.each do |duplicates|
      duplicates.shift
      duplicates.each { |double| double.destroy }
    end
  end

  desc "test scrape single tournament"
  task :single_scrape_tournaments_details => :environment do
    #ba_ids = Array(ENV["BA_ID"].presence || [4465])
    #ba_ids = Tournament.where(discipline_id: Discipline.find_by_name("Pool").id).map(&:ba_id).sort
    ba_ids = [6040]
    Tournament.where(ba_id: ba_ids).all.each do |t|
      scrape_single_tournament(t, game_details: true)
      t.update_columns(last_ba_sync_date: Time.now)
    end
  end

  desc "update tournaments"
  task :update_tournaments => :environment do

    logger = Logger.new("#{Rails.root}/log/scrape.log")
    env_season_name = ENV['SEASON']
    env_region_shortname = ENV['REGION']

    Season.order(ba_id: :desc).limit(2).each do |season|
      #Season.order(ba_id: :desc).each do |season|
      next unless env_season_name.present? && season.name == env_season_name
      Region.all.each do |region|
        #next unless region.id == 12
        region_ba_ids = region.tournaments.where(season_id: season.id).map(&:ba_id)
        #uncompleted_region_ba_ids = region.tournaments.where(ba_id: region_ba_ids, ba_state: "").where("date < ?", Time.now - 1.day).where("date > ?", Time.now - 2.month).map(&:ba_id)
        uncompleted_region_ba_ids = region.tournaments.where(ba_id: region_ba_ids).map(&:ba_id)
        #uncompleted_region_ba_ids = region.tournaments.where(ba_id: 6040, ba_state: "").map(&:ba_id)
        next unless env_region_shortname.present? && region.shortname == env_region_shortname
        url = "https://#{region.shortname.downcase}.billardarea.de"
        uri = URI(url + '/cms_single')
        Rails.logger.info "reading #{url + '/cms_single'} - region #{region.shortname} single tournaments season #{season.name}"
        res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
        doc = Nokogiri::HTML(res.body)
        tabs = doc.css("#tabs a")
        tabs.each_with_index do |tab, ix|
          tab_text = tab.text.strip
          if Discipline::DE_DISCIPLINE_NAMES.include?(tab_text)
            discipline_name = Discipline::DISCIPLINE_NAMES[Discipline::DE_DISCIPLINE_NAMES.index(tab_text)]
            discipline_name = discipline_name.presence || "-"
            discipline = Discipline.find_by_name(discipline_name) || Discipline.create(name: discipline_name)
            tables = doc.css("#tabs-#{ix + 1} table")
            tables.each_with_index do |table, table_no|
              lines = table.css("tr")
              lines.map do |line|
                tournament_ba_closed = false
                name = nil
                url = nil
                cols = line.css("td")
                cols.each do |col|
                  if col.css("a").present?
                    field = col.css("a").first
                    name = field.text.strip
                    url = field.attribute("href").value
                    Rails.logger.info "----#{name} #{url}"
                  elsif col.text.strip == "X"
                    tournament_ba_closed = true
                  end
                end
                next unless name.present? && url.present?
                m = url.match(/\/cms_(single|leagues)\/(plan|show)\/(\d+)$/)
                ba_id = m[3] rescue nil
                single_or_league = m[1] rescue nil
                plan_or_show = m[2] rescue nil
                if !region_ba_ids.include?(ba_id.to_i) || (uncompleted_region_ba_ids.include?(ba_id.to_i) && table_no == 0)
                  if ba_id.present?
                    tournament = Tournament.find_by_ba_id(ba_id)
                    if tournament.present? && tournament.discipline.blank?
                      tournament.update(discipline: discipline)
                    end
                    tournament ||=
                      Tournament.create(ba_id: ba_id, title: name, region_id: region.id, season_id: season.id, discipline: discipline)
                    tournament.update(plan_or_show: plan_or_show, single_or_league: single_or_league, ba_state: tournament_ba_closed ? "X" : "")
                    scrape_single_tournament(tournament, logger: logger)
                    tournament.update_columns(last_ba_sync_date: Time.now)
                  else
                    ba_id
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  desc "create local seed"
  task :create_local_seed => :environment do
    output = ""
    void_keys = { "User" => ["terms_of_service"], "Account" => ["quantity", "plan", "card_token"] }
    %w{User Account AccountUser Player Tournament Seeding Game GameParticipation TournamentMonitor TableMonitor TournamentLocal Location Table}.each do |classz|
      output << "#{classz.underscore}_id_map = {}\n"
      if classz == "Account"
        output << "#+++Account+++\n"
        output << "#---User---\n"
        output << "h1 = JSON.pretty_generate(user_id_map)\n"
      elsif classz == "AccountUser"
        output << "#+++AccountUser+++\n"
        output << "#---Account---\n"
        output << "h1 = JSON.pretty_generate(account_id_map)\n"
        output << "#---User---\n"
        output << "h2 = JSON.pretty_generate(user_id_map)\n"
      elsif classz == "TournamentMonitor\n"
        output << "#+++TournamentMonitor+++\n"
        output << "#---Tournament---\n"
        output << "h1 = JSON.pretty_generate(tournament_id_map)\n"
      elsif classz == "Game"
        output << "#---Tournament---\n"
        output << "h1 = JSON.pretty_generate(tournament_id_map)\n"
      elsif classz == "Location"
      elsif classz == "table"
        output << "#---Location---\n"
        output << "h1 = JSON.pretty_generate(location_id_map)\n"
      elsif classz == "GameParticipation"
        output << "#+++GameParticipation+++\n"
        output << "#---Player---\n"
        output << "h1 = JSON.pretty_generate(player_id_map)\n"
        output << "#---Game---\n"
        output << "h2 = JSON.pretty_generate(game_id_map)\n"
      elsif classz == "Seeding"
        output << "#+++Seeding+++\n"
        output << "#---Tournament---\n"
        output << "h1 = JSON.pretty_generate(tournament_id_map)\n"
        output << "#---Player---\n"
        output << "h2 = JSON.pretty_generate(player_id_map)\n"
      elsif classz == "TableMonitor"
        output << "#+++TableMonitor+++\n"
        output << "#---TournamentMonitor---\n"
        output << "h1 = JSON.pretty_generate(tournament_monitor_id_map)\n"
      elsif classz == "User"
      end
      classz.constantize.where("id >= 50000000").order(:id).all.each do |obj|
        time_keys = %w{date created_at updated_at started_at ended_at accepted_terms_at accepted_privacy_at announcements_read_at invitation_created_at invitation_accepted_at timer_start_at timer_finish_at timer_halt_at trial_ends_at ends_at }
        hash_keys = %w{data roles}
        attrs = obj.serializable_hash.delete_if { |key, value| (hash_keys + time_keys + void_keys[classz].to_a).include?(key) }.to_s.gsub(/[{}]/, '')
        time_keys.each do |key|
          if obj.respond_to?(:"#{key}") && obj.send(:"#{key}").present?
            output << "#{key} = Time.at(#{obj.send("#{key}").to_f})\n"
            attrs += ", #{key}: #{key}"
          end
        end
        output << "obj_was = #{classz.constantize}.where(#{attrs}).first\n"
        output << "if obj_was.blank?\n"
        attrs_no_id = obj.serializable_hash.delete_if { |key, value| (["id"] + hash_keys + time_keys + void_keys[classz].to_a).include?(key) }.to_s.gsub(/[{}]/, '')
        output << "  obj_was = #{classz.constantize}.where(#{attrs_no_id}).first\n"
        output << "  if obj_was.blank?\n"
        output << "    obj = #{classz.constantize}.new(#{obj.serializable_hash.delete_if { |key, value| (["id"] + hash_keys + time_keys + void_keys[classz].to_a).include?(key) }.to_s.gsub(/[{}]/, '')})\n"
        if classz == "Account"
          output << "    obj.owner_id = user_id_map[#{obj.owner_id}] if user_id_map[#{obj.owner_id}].present?\n" if obj.owner_id.present?
          output << "    obj.plan = nil\n"
          output << "    obj.quantity = nil\n"
          output << "    obj.card_token = nil\n"
        elsif classz == "AccountUser"
          output << "    obj.account_id = account_id_map[#{obj.account_id}] if account_id_map[#{obj.account_id}].present?\n" if obj.account_id.present?
          output << "    obj.user_id = user_id_map[#{obj.user_id}] if user_id_map[#{obj.user_id}].present?\n" if obj.user_id.present?
        elsif classz == "TournamentMonitor"
          output << "    obj.tournament_id = tournament_id_map[#{obj.tournament_id}] if tournament_id_map[#{obj.tournament_id}].present?\n" if obj.tournament_id.present?
        elsif classz == "Game"
          output << "    obj.tournament_id = tournament_id_map[#{obj.tournament_id}] if tournament_id_map[#{obj.tournament_id}].present?\n" if obj.tournament_id.present?
        elsif classz == "GameParticipation"
          output << "    obj.game_id = game_id_map[#{obj.game_id}] if game_id_map[#{obj.game_id}].present?\n" if obj.game_id.present?
        elsif classz == "Table"
          output << "    obj.location_id = location_id_map[#{obj.location_id}] if location_id_map[#{obj.location_id}].present?\n" if obj.location_id.present?
        elsif classz == "Seeding"
          output << "    obj.tournament_id = tournament_id_map[#{obj.tournament_id}] if tournament_id_map[#{obj.tournament_id}].present?\n" if obj.tournament_id.present?
          output << "    obj.player_id = player_id_map[#{obj.player_id}] if player_id_map[#{obj.player_id}].present?\n"
        elsif classz == "TableMonitor"
          output << "    obj.tournament_monitor_id = tournament_monitor_id_map[#{obj.tournament_monitor_id}] if tournament_monitor_id_map[#{obj.tournament_monitor_id}].present?\n" if obj.tournament_monitor_id.present?
          output << "    obj.game_id = game_id_map[#{obj.id}] if game_id_map[#{obj.game_id}].present?\n" if obj.game_id.present?
        elsif classz == "User"
          output << "    obj.password = \"******\"\n"
          output << "    obj.terms_of_service = true\n"
        end
        hash_keys.each do |key|
          if obj.respond_to?(:"#{key}") && obj.send(:"#{key}").present?
            output << "    #{key} = #{obj.send("#{key}").inspect}\n"
            output << "    obj.#{key} = #{key}\n"
          end
        end
        time_keys.each do |key|
          if obj.respond_to?(:"#{key}") && obj.send(:"#{key}").present?
            output << "    #{key} = Time.at(#{obj.send("#{key}").to_f})\n"
          end
        end
        output << "    begin\n"
        output << "      obj.save!\n"
        if classz == "User"
          output << "      obj.update_column(:encrypted_password, \"#{obj.encrypted_password}\")\n"
        end
        output << "      id = obj.id\n"
        output << "      #{classz.underscore}_id_map[#{obj.id}] = id\n"
        time_keys.each do |key|
          if obj.respond_to?(:"#{key}") && obj.send(:"#{key}").present?
            output << "      obj.update_column(:\"#{key}\", #{key})\n"
          end
        end
        output << "    rescue StandardError => e\n"
        output << "    end\n"
        output << "  else\n"

        output << "    id = obj_was.id\n"
        output << "    #{classz.underscore}_id_map[#{obj.id}] = id\n"

        output << "  end\n"
        output << "end\n"
      end
    end
    f = File.new("#{Rails.root}/db/seeds.rb", "w")
    f.write(output)
    f.close
  end

  desc "fix game participations"
  task :fix_game_participations => :environment do
    # Game.all.each do |game|
    #   Game.fix_participation(game)
    # end
    Game.all.each do |game|
      gname = game.data["Gr."]
      game.update(gname: gname) if gname.present?
    end
    #Game.fix_participation(Game[42855])
  end

  desc "update ranking tables"
  task :update_ranking_tables => :environment do
    # for all seasons - starting with earliest
    season_from = ENV["SEASON_FROM"] ||= Season.order(name: :desc).to_a[2].name
    #Season.order(ba_id: :asc).where("name >= ?", season_from).each do |season|
    Season.order(ba_id: :asc).each do |season|
      # for all regions
      # TEST
      #next unless season.name == "2018/2019"
      Region.all.each do |region|
        # for all disciplines
        # TEST
        #next unless region.shortname == "NBV"
        Discipline.all.each do |discipline|
          # for all relevant tournaments
          # TEST
          next unless discipline.root.name == "Carambol"
          players = {}
          Tournament.where(season: season, organizer_type: "Region", organizer_id: region.id, discipline: discipline).each do |tournament|
            # for all participants
            sum_keys = %w{Sp.G Sp.V G V Bälle Aufn Punkte Frames Partiepunkte Satzpunkte Kegel}
            max_keys = %w{Sp.Quote Quote GD HB HS HGD BED}
            ignore_keys = %w{# Name Verein Rank}
            computes = %w{GD:Bälle/Aufn Quote:100*G/V Sp.Quote:100*Sp.G/Sp.V}
            tournament.seedings.includes(:player).each do |seeding|
              player_record = players[seeding.player.id]
              gl = seeding.data["result"]["Gesamtrangliste"] rescue {}
              unless player_record.present?
                players[seeding.player.id] = {}
                if (gl.keys - (ignore_keys + sum_keys + max_keys)).present?
                  xxx
                end
                ((max_keys | sum_keys) & gl.keys).each do |k|
                  players[seeding.player.id][k] = 0
                end
                players[seeding.player.id]["t_ids"] = []
              end
              players[seeding.player.id]["t_ids"] << tournament.id
              (sum_keys & gl.keys).each do |k|
                players[seeding.player.id][k] = (players[seeding.player.id][k] || 0) + gl[k].to_i
              end
              (max_keys & gl.keys).each do |k|
                v = gl[k]
                if v =~ /%/
                  vf = (v.gsub(/\s*%/, "").gsub(",", ".")).to_f
                  pf = players[seeding.player.id][k] || 0
                  players[seeding.player.id][k] = [vf, pf].max
                elsif v =~ /,/
                  vf = (v.gsub(",", ".")).to_f
                  pf = players[seeding.player.id][k] || 0
                  players[seeding.player.id][k] = [vf, pf].max
                else
                  vi = v.to_i
                  pi = players[seeding.player.id][k] || 0
                  players[seeding.player.id][k] = [vi, pi].max
                end
              end
            end
          end
          players.keys.select do |player_id|
            values = players[player_id]
            values["Bälle"].to_f > 0 && values["Aufn"].to_f > 0
          end.
            sort_by do |player_id|
            values = players[player_id]
            100.0 * values["Bälle"] / values["Aufn"]
          end.reverse.
            each_with_index do |player_id, ix|
            args = {
              player_id: player_id,
              region_id: region.id,
              season_id: season.id,
              discipline_id: discipline.id
            }
            values = players[player_id]
            player_ranking = PlayerRanking.where(args).first
            player_ranking ||= PlayerRanking.create(args)
            data = player_ranking.remarks
            data["result"] = values
            attributes = {}
            values.keys.each do |k|
              mapped_k = PlayerRanking::KEY_MAPPINGS[k]
              attributes[mapped_k] = values[k]
            end
            attributes[:remarks] = data
            attributes[:rank] = ix + 1
            player_ranking.update(attributes)
          end
        end
      end
    end
  rescue StandardError => e
    e
  end

  desc "generate locations"
  task :generate_locations => :environment do
    Tournament.includes(:organizer, :region).order("tournaments.ba_id asc").each do |t|
      @location = nil
      @organizer = t.organizer || t.region
      @address_a = t.location.andand.split("\n").andand.map(&:strip)
      if @address_a.present?
        @name = @address_a.shift
        @address = @address_a.join("\n")
        @location = Location.where(name: @name, address: @address, organizer: @organizer).first_or_create!
      end
      t.tournament_location = @location
      t.save!
    end
  end
  desc "scrape new tournaments"
  task :scrape_new_tournaments => :environment do
    itest = Tournament.order(:ba_id => :desc).first.ba_id
    ip = 14
    url = "https://nbv.billardarea.de"
    dir = 1
    while ip >= 0
      itest = itest + dir * 2 ** ip
      url_tournament = "/cms_single/show/#{itest}"
      uri = URI(url + url_tournament)
      res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{Season.last.ba_id}")
      doc = Nokogiri::HTML(res.body)
      valid_tournament = true
      doc.css(".element").each do |element|
        label = element.css("label").text.strip
        value = Array(element.css(".field")).map(&:text).map(&:strip).join("\n")
        if label == "Meisterschaft" && value.blank?
          valid_tournament = false
          break
        end
      end
      ip -= 1
      dir = valid_tournament ? 1 : -1
    end
    range = (Tournament.order(:ba_id => :desc).first.ba_id..(itest - 1))
    Season.last.scrape_tournaments(range.to_a)
  end
end

def scrape_single_tournament(tournament)
  tournament.scrape_single_tournament(force_immediate_action: true)
end

