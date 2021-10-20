# encoding: utf-8
require "#{Rails.root}/app/helpers/application_helper"
require 'open-uri'
require 'uri'
require 'net/http'

include ApplicationHelper

DE_DISCIPLINE_NAMES = ["Pool", "Snooker", "Kegel", "5 Kegel", "Karambol großes Billard", "Karambol kleines Billard", "Biathlon"]
DISCIPLINE_NAMES = ["Pool", "Snooker", "Pin Billards", "5-Pin Billards", "Carambol Match Billard", "Carambol Small Billard", "Biathlon"]

TABLE_KINDS = ["Pool", "Snooker", "Small Billard", "Half Match Billard", "Match Billard"]

TABLE_KIND_DISCIPLINE_NAMES = {
  "Pin Billards" => [],
  "Biathlon" => [],
  "5-Pin Billards" => [],
  "Pool" => ["9-Ball", "8-Ball", "14.1 endlos", "Blackball"],
  "Small Billard" => ["Dreiband klein", "Freie Partie klein", "Einband klein", "Cadre 52/2", "Cadre 35/2", "Biathlon", "Nordcup", "Petit/Grand Prix"],
  "Match Billard" => ["Dreiband groß", "Einband groß", "Freie Partie groß", "Cadre 71/2", "Cadre 47/2", "Cadre 47/1"],
  "Half Match Billard" => ["Cadre 38/2", "Cadre 57/2"] }

namespace :carambus do

  desc "eliminate location duplicates"
  task :eliminate_location_duplicates => :environment do

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

    Season.where(ba_id: [12, 13]).order(name: :desc).each do |season|
      Region.all.each do |region|
        #if region.shortname.downcase == 'nbv'
        #if ["BVNRW"].include?(region.shortname)
        url = "https://#{region.shortname.downcase}.billardarea.de"
        Rails.logger.info "reading #{url + '/cms_clubs'} - region clubs"
        html = open(url + '/cms_clubs')
        force = false
        doc = Nokogiri::HTML(html)
        club_details = doc.css("td:nth-child(2) a").map { |d| d.attribute("href").value }
        club_details.each do |club_detail|
          club_ba_id = club_detail.match(/.*\/(\d+)$/).andand[1].to_i
          club = Club.find_by_ba_id(club_ba_id) || Club.new(ba_id: club_ba_id, region_id: region.id)
          club.scrape_single_club(player_details: true, season: season, force_update: force)
        end
      end
    end
    #fix title
    Player.where("title ~ 'Herr.'").update_all(title: 'Herr')
    Player.where("title ~ 'Frau.'").update_all(title: 'Frau')
  end

  desc "scrape Players"
  task :scrape_players => :environment do
    Player.includes(:club => :region).each do |player|
      url = "https://#{player.club.region.shortname.downcase}.billardarea.de"
      player_details_url = "#{url}/cms_clubs/playerdetails/#{club.ba_id}/#{player.ba_id}"
      Rails.logger.info "reading #{player_details_url} - player details of player [#{player.ba_id}] on club #{club.shortname} [#{club.ba_id}]"
      html_player_detail = open(player_details_url)
      doc_player_detail = Nokogiri::HTML(html_player_detail)
      player_ba_id = doc_player_detail.css("#tabs-1 fieldset:nth-child(1) legend+ .element .field").text.strip.to_i
      if player_ba_id == player.ba_id
        player_title = doc_player_detail.css("#tabs-1 fieldset:nth-child(1) .element:nth-child(3) .field").text.strip
        player_lastname, player_firstname = doc_player_detail.css("#tabs-1 fieldset:nth-child(1) .element:nth-child(4) .field").text.strip.split(", ")
        player.update(title: player_title, lastname: player_lastname, firstname: player_firstname)
      end
    end
  end

  desc "retrieve updates from API server"
  task :retrieve_updates => :environment do
    Version.update_from_carambus_api
  end

  desc "Init Disciplines"
  task :init_disciplines => :environment do
    TABLE_KIND_DISCIPLINE_NAMES.each do |tk_name, v|
      tk = TableKind.find_by_name(tk_name) ||
        TableKind.create(name: tk_name)
      v.each do |dis_name|
        Discipline.create(name: dis_name, table_kind_id: tk.id) unless Discipline.find_by_name_and_table_kind_id(dis_name, tk.id).present?
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

    Season.order(name: :desc).each do |season|
      Region.all.each do |region|
        #next unless region.shortname == "NBV"
        url = "https://#{region.shortname.downcase}.billardarea.de"
        uri = URI(url + '/cms_single')
        Rails.logger.info "reading #{url + '/cms_single'} - region #{region.shortname} single tournaments season #{season.name}"
        res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
        doc = Nokogiri::HTML(res.body)
        tabs = doc.css("#tabs a")
        tabs.each_with_index do |tab, ix|
          tab_text = tab.text.strip
          if DE_DISCIPLINE_NAMES.include?(tab_text)
            discipline_name = DISCIPLINE_NAMES[DE_DISCIPLINE_NAMES.index(tab_text)]
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
                tournament = Tournament.find_by_ba_id(ba_id) || Tournament.create(ba_id: ba_id, discipline_id: Discipline.find_by_name("-"))
                tournament.scrape_single_tournament(game_details: true)
                tournament.update(title: name, region_id: region.id, discipline_id: discipline.id, season_id: season.id, plan_or_show: plan_or_show, single_or_league: single_or_league, organizer: region)
                tournament.update_columns(last_ba_sync_date: Time.now)
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

    Season.order(ba_id: :desc).limit(2).each do |season|
      #Season.order(ba_id: :desc).each do |season|
      #next unless season.name == "2013/2014"
      Region.all.each do |region|
        #next unless region.id == 12
        region_ba_ids = region.tournaments.where(season_id: season.id).map(&:ba_id)
        #uncompleted_region_ba_ids = region.tournaments.where(ba_id: region_ba_ids, ba_state: "").where("date < ?", Time.now - 1.day).where("date > ?", Time.now - 2.month).map(&:ba_id)
        uncompleted_region_ba_ids = region.tournaments.where(ba_id: region_ba_ids).map(&:ba_id)
        #uncompleted_region_ba_ids = region.tournaments.where(ba_id: 6040, ba_state: "").map(&:ba_id)
        #next unless region.shortname == "NBV"
        url = "https://#{region.shortname.downcase}.billardarea.de"
        uri = URI(url + '/cms_single')
        Rails.logger.info "reading #{url + '/cms_single'} - region #{region.shortname} single tournaments season #{season.name}"
        res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
        doc = Nokogiri::HTML(res.body)
        tabs = doc.css("#tabs a")
        tabs.each_with_index do |tab, ix|
          tab_text = tab.text.strip
          if DE_DISCIPLINE_NAMES.include?(tab_text)
            discipline_name = DISCIPLINE_NAMES[DE_DISCIPLINE_NAMES.index(tab_text)]
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
    %w{User Account AccountUser TournamentMonitor Tournament TableMonitor Game Seeding GameParticipation}.each do |classz|
      classz.constantize.where("id >= 50000000").order(:id).all.each do |obj|
        output << "obj = #{classz.constantize}.new(#{obj.serializable_hash.delete_if {|key, value| ['created_at','updated_at'].include?(key)}.to_s.gsub(/[{}]/,'')})\n"
        output << "obj.save!\n"
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
            player_ranking = PlayerRanking.where(args).first || PlayerRanking.create(args)
            data = player_ranking.data
            data["result"] = values
            attributes = {}
            values.keys.each do |k|
              mapped_k = PlayerRanking::KEY_MAPPINGS[k]
              attributes[mapped_k] = values[k]
            end
            attributes[:data] = data
            attributes[:rank] = ix + 1
            player_ranking.update(attributes)
          end
        end
      end
    end

  end
end

def scrape_single_tournament(tournament, opts = {})
  tournament.scrape_single_tournament(opts = {})
end

