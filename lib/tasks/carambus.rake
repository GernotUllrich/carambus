# encoding: utf-8
require "#{Rails.root}/app/helpers/application_helper"
require 'open-uri'
require 'net/http'

include ApplicationHelper

namespace :carambus do

  desc "scrape regions"
  task :scrape_regions => :environment do
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
      r.update_attributes(name: region_name, shortname: region_shortname, logo: region_logo, country: country_de)
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
    (2009..(Date.today.year)).each_with_index do |year, ix|
      Season.find_by_name("#{year}/#{year + 1}") || Season.create(ba_id: ix + 1, name: "#{year}/#{year + 1}")
    end
  end

  desc "scrape clubs"
  task :scrape_clubs => :environment do

    Season.where(ba_id: [3, 2, 1]).order(name: :desc).each do |season|
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
          detail_url = url + club_detail

          force_update = false
          Rails.logger.info "reading #{detail_url} - club details"
          detail_uri = URI(detail_url)
          res = Net::HTTP.post_form(detail_uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
          doc_detail = Nokogiri::HTML(res.body)
          club_logo = doc_detail.css("\#tabs-1 img").text.strip
          club_ba_id = club_detail.match(/.*\/(\d+)$/).andand[1].to_i
          club_name = doc_detail.css(".left fieldset:nth-child(1) .element").text.strip
          club_shortname = doc_detail.css(".left fieldset:nth-child(2) .element").text.strip
          club_homepage = doc_detail.css("\#tabs-1 a:nth-child(1)").text.strip
          club_players = doc_detail.css("\#clubs_table a").map { |d| d.attribute("href").value.match(/.*\/(\d+)$/).andand[1].to_i }

          tab1 = doc_detail.css("\#tabs-1")
          club_email = doc_detail.css("\#tabs-1").children[1].children[9].text.strip.gsub(/.*;< (.*) >.*/, '\1').gsub(/[\t\r\n]/, "").gsub("Email", "").reverse
          club_priceinfo = doc_detail.css("pre").text.strip
          club_status = doc_detail.css(".right fieldset:nth-child(1) .element").text.strip
          club_founded = doc_detail.css(".right fieldset:nth-child(2) .element").text.strip
          club_dbu_entry = doc_detail.css(".right fieldset~ fieldset+ fieldset .element").text.strip
          club = Club.find_by_ba_id(club_ba_id) || Club.new(ba_id: club_ba_id)
          club.update_attributes(
              name: club_name,
              shortname: club_shortname,
              homepage: club_homepage,
              email: club_email,
              priceinfo: club_priceinfo,
              status: club_status,
              founded: club_founded,
              dbu_entry: club_dbu_entry,
              region: region,
              logo: club_logo
          )
          club_players.each do |id|
            player = Player.find_by_ba_id(id)
            skip_details = player.present? && !force_update
            player ||= Player.new()
            player.update_attributes(ba_id: id, club_id: club.id)
            sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player.id, season.id, club.id) ||
                SeasonParticipation.create(player_id: player.id, season_id: season.id, club_id: club.id)
            unless skip_details
              url = "https://#{region.shortname.downcase}.billardarea.de"
              player_details_url = "#{url}/cms_clubs/playerdetails/#{club.ba_id}/#{player.ba_id}"
              Rails.logger.info "reading #{player_details_url} - player details of player [#{player.ba_id}] on club #{club.shortname} [#{club.ba_id}]"
              html_player_detail = open(player_details_url)
              doc_player_detail = Nokogiri::HTML(html_player_detail)
              player_ba_id = doc_player_detail.css("#tabs-1 fieldset:nth-child(1) legend+ .element .field").text.strip.to_i
              if player_ba_id == player.ba_id
                player_title = doc_player_detail.css("#tabs-1 fieldset:nth-child(1) .element:nth-child(3) .field").text.strip
                player_lastname, player_firstname = doc_player_detail.css("#tabs-1 fieldset:nth-child(1) .element:nth-child(4) .field").text.strip.split(", ")
                player.update_attributes(title: player_title, lastname: player_lastname, firstname: player_firstname)
              end
            end
          end
        end
      end
      #end
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
        player.update_attributes(title: player_title, lastname: player_lastname, firstname: player_firstname)
      end
    end
  end

  desc "Init Disciplines"
  task :init_disciplines => :environment do

    TABLE_KINDS = ["Pool", "Snooker", "Small Table", "Match Table", "Large Table"]

    TABLE_TYPES = {
        "gross" => ["Freie Partie", "Cadre 47/2", "Cadre 47/1", "Cadre 71/2", "Einband", "Dreiband"],
        "match" => ["Freie Partie", "Cadre 38/2", "Cadre 38/1", "Cadre 57/2", "Einband", "Dreiband"],
        "klein" => ["Freie Partie", "Cadre 35/2", "Cadre 35/1", "Cadre 52/2", "Einband", "Dreiband"],
    }

    # first migration only
    # TABLE_TYPES.each do |k,v|
    #   v.each do |dd|
    #     d = Discipline.find_by_name(dd, k) || Discipline.create(name: dd, table_size: k)
    #   end
    # end

    TABLE_KINDS.each do |table_name|
      TableKind.find_by_name(table_name) || TableKind.create!(name: table_name)
    end

    Discipline::MAJOR_DISCIPLINES.each do |discipline_name, value|
      d = Discipline.find_by_name(discipline_name) || Discipline.create(name: discipline_name)
    end

    Discipline.all.each do |discipline|
      case discipline.table_size
      when "klein"
        unless discipline.name =~ /kleiner Tisch$/
          discipline.short_name = discipline.name + " - klein"
          discipline.name = discipline.name + " - kleiner Tisch"
          discipline.table_kind_id = TableKind.find_by_name("Small Table").andand.id
          discipline.super_discipline_id = Discipline.find_by_name("Carambol Small Table").andand.id
          discipline.save
        end
      when "gross"
        unless discipline.name =~ /grosser Tisch$/
          discipline.short_name = discipline.name + " - gross"
          discipline.name = discipline.name + " - grosser Tisch"
          discipline.table_kind_id = TableKind.find_by_name("Large Table").andand.id
          discipline.super_discipline_id = Discipline.find_by_name("Carambol Large Table").andand.id
          discipline.save
        end
      when "match"
        unless discipline.name =~ /Match Tisch$/
          discipline.short_name = discipline.name + " - match"
          discipline.name = discipline.name + " - Match Tisch"
          discipline.table_kind_id = TableKind.find_by_name("Large Table").andand.id
          discipline.super_discipline_id = Discipline.find_by_name("Carambol Match Table").andand.id
          discipline.save
        end
      end
    end
  end

  desc "Init TournamentTemplates"
  task :init_tournament_templates => :environment do
    # c&p from file NBV%20STO%20BT%20Karambolage%2023-06-2019.pdf
    STR = "Freie Partie Kl. 1 250 15 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nFreie Partie Kl. 2 200 15 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nFreie Partie Kl. 3 150 15 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nFreie Partie Kl. 4 150 20 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nFreie Partie Kl. 5 100 20 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nFreie Partie Kl. 6 80 20 T0 T1 T2 T3 T4 T7 T12 T15 T16 T18 T21 T24\nFreie Partie Kl. 7 40 20 T0 T1 T2 T3 T4 T7 T12 T15 T16 T18 T21 T24\nCadre 35/2 Kl. 1 200 15 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nCadre 35/2 Kl. 2 100 20 T0 T1 T2 T3 T4 T7 T12 T15 T16 T18 T21 T24\nCadre 52/2 Kl. 1 150 15 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nCadre 52/2 Kl. 2 80 20 T0 T1 T2 T3 T4 T7 T12 T15 T16 T18 T21 T24\nEinband Kl. 1 100 20 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nEinband Kl. 2 50 25 T0 T1 T2 T3 T4 T7 T12 T15 T16 T18 T21 T24\nDreiband Kl. 1 30 25 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nDreiband Kl. 2 20 25 T0 T1 T2 T3 T4 T7 T12 T15 T16 T18 T21 T24\nFreie Partie Kl. I 300 15 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nFreie Partie Kl. II 200 20 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nFreie Partie Kl. III 100 20 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nCadre 47/2 Kl. I 200 15 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nCadre 47/2 Kl. II 150 20 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nCadre 71/2 Kl. I 150 15 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nCadre 71/2 Kl. II 40 20 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nEinband Kl. I 100 20 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nEinband Kl. II 75 25 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T21 T23\nDreiband Kl. I 40 50 T0 T1 T2 T3 T5 T8 T11 T14 T17 T19 T22 T23\nDreiband Kl. II 25 40 T0 T1 T2 T3 T4 T6 T9 T13 T17 T19 T22 T23\nDreiband Kl. III 20 40 T0 T1 T2 T3 T4 T6 T9 T13 T16 T18 T22 T23\nPetit/Grand Prix 0 0 T0 T0 T0 T3 T4 T7 T12 T15 T16 T18 T21 T24\nNordcup 0 0 T0 T0 T0 T3 T4 T6 T9 T13 T16 T18 T21 T23"
    dis = STR.split("\n").map { |d| m = d.match(/(.*) (\d+) (\d+) (T\d+) (T\d+) (T\d+) (T\d+) (T\d+) (T\d+) (T\d+) (T\d+) (T\d+) (T\d+) (T\d+) (T\d+)\s*/); m[1..-1] }

    dis.each do |l|
      d = TournamentTemplate.find_by_name(l[0]) || TournamentTemplate.new(name: l[0])
      d.update_attributes(points: l[1].to_i, innings: l[2].to_i)
      (1..12).each do |iplayers|
        tn = l[iplayers + 2]
        t = Template.find_by_name(tn) || Template.new(name: tn)
        t.update_attributes(players: iplayers)
        dt = PlayerCountTemplate.find_by_tournament_template_id_and_players(d.id, iplayers) || PlayerCountTemplate.new(tournament_template_id: d.id, players: iplayers)
        dt.update_attributes(template_id: t.id)
      end
    end
    TournamentTemplate.includes(:discipline).each do |t|
      dis = t.name.gsub(/ Kl\. .*/, "")
      size = (t.name =~ /I$/) ? "gross" : "klein"
      discipline = Discipline.find_by_name_and_table_size(dis, size) || Discipline.create(name: dis, table_size: size)
      t.update_attributes(discipline_id: discipline.id)
    end
  end

  desc "Scrape Tournaments"
  task :scrape_tournaments => :environment do
    DE_DISCIPLINE_NAMES = ["Pool", "Snooker", "Kegel", "5 Kegel", "Karambol großes Billard", "Karambol kleines Billard", "Biathlon"]
    DISCIPLINE_NAMES = ["Pool", "Snooker", "Pin Billards", "5-Pin Billards", "Carambol Large Table", "Carambol Small Table", "Biathlon"]

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
                tournament.update_attributes(title: name, region_id: region.id, discipline_id: discipline.id, season_id: season.id, state: plan_or_show, single_or_league: single_or_league)
              else
                ba_id
              end
            end
          else
            tab_text
            break
          end
        end
      end
    end
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
          scrape_single_tournament(tournament, logger) if on
        end
      end
    end
  end

  desc "remove duplicate season participations"
  task :remove_duplicate_season_participations => :environment do
    grouped = SeasonParticipation.all.group_by { |s| [s.player_id, s.club_id, s.season_id] }
    grouped.values.each do |duplicates|
      first_one = duplicates.shift
      duplicates.each { |double| double.destroy }
    end
  end

  desc "fix disciplines"
  task :fix_disciplines => :environment do

    discipline_mappings = {
        "Freie Partie - grosser Tisch" => "Freie Partie gross",
        "Cadre 47/2 - grosser Tisch" => "Cadre 47/2 gross",
        "Cadre 47/1 - grosser Tisch" => "Cadre 47/1 gross",
        "Cadre 71/2 - grosser Tisch" => "Cadre 71/2 gross",
        "Einband - grosser Tisch" => "Einband gross",
        "Dreiband - grosser Tisch" => "Dreiband gross",
        "Freie Partie - kleiner Tisch" => "Freie Partie klein",
        "Cadre 35/2 - kleiner Tisch" => "Cadre 35/2 klein",
        "Cadre 35/1 - kleiner Tisch" => "Cadre 35/1 klein",
        "Cadre 52/2 - kleiner Tisch" => "Cadre 52/2 klein",
        "Einband - kleiner Tisch" => "Einband klein",
        "Dreiband - kleiner Tisch" => "Dreiband klein",
        "Petit/Grand Prix - kleiner Tisch" => "Petit/Grand Prix klein",
        "Nordcup - kleiner Tisch" => "Nordcup klein",
        "Cadre 47/2 - kleiner Tisch" => "Cadre 47/2 gross",
        "Cadre 71/2 - kleiner Tisch" => "Cadre 71/2 gross",
    }
    discipline_mappings.each do |alt, neu|
      discipline_alt_id = Discipline.find_by_name(alt)
      discipline_neu_id = Discipline.find_by_name(neu)
      Tournament.where(discipline_id: discipline_alt_id).update_all(discipline_id: discipline_neu_id)
    end
  end

  desc "fix game participations"
  task :fix_game_participations => :environment do
    # Game.all.each do |game|
    #   Game.fix_participation(game)
    # end
    Game.all.each do |game|
      gname = game.remarks["Gr."]
      game.update_attributes(gname: gname) if gname.present?
    end
    #Game.fix_participation(Game[42855])
  end
end

def scrape_single_tournament(tournament, logger)
  season = tournament.season
  region = tournament.region
  url = "https://#{region.shortname.downcase}.billardarea.de"
  if tournament.single_or_league == "single"
    url_tournament = "/cms_#{tournament.single_or_league}/show/#{tournament.ba_id}"
    Rails.logger.info "reading #{url + url_tournament} - tournament \"#{tournament.title}\" season #{season.name}"
    uri = URI(url + url_tournament)
    res = Net::HTTP.post_form(uri, 'data[Season][check]' => '87gdsjk8734tkfdl', 'data[Season][season_id]' => "#{season.ba_id}")
    doc = Nokogiri::HTML(res.body)
    doc.css(".element").each do |element|
      label = element.css("label").text.strip
      value = Array(element.css(".field")).map(&:text).map(&:strip).join("\n")
      mappings = {
          "Meisterschaft" => :title,
          "Datum" => :data, # 13.05.2021	(09:00 Uhr) - 14.05.2021
          "Meldeschluss" => :accredation_end, # 27.10.2020 (23:59 Uhr)
          "Kurzbezeichnung" => :shortname,
          "Disziplin" => :discipline,
          "Spielmodus" => :modus,
          "Altersklasse" => :age_restriction,
          "Spiellokal" => :location,
      }
      case label
      when "Datum"
        date_begin, time_begin, date_end = value.match(/\s*(\d+\.\d+\.\d+)\s*(?:\((.*) Uhr\))?(?:\s+\-\s+(\d+\.\d+\.\d+))?.*/).to_a[1..-1]
        tournament.date = DateTime.parse(date_begin + "#{" #{time_begin}" if time_begin.present?}")
        tournament.end_date = DateTime.parse(date_end) if date_end.present?
      when "Meldeschluss"
        date_begin, time_begin = value.match(/\s*(\d+\.\d+\.\d+)\s*(?:\((.*) Uhr\))?.*/).to_a[1..-1]
        tournament.accredation_end = DateTime.parse(date_begin + "#{" #{time_begin}" if time_begin.present?}")
      when "Disziplin"
        specified_discipline = tournament.discipline unless (tournament.discipline.present? && tournament.discipline.name =~ /Carambol (Large|Small) Table/)
        discipline = specified_discipline || Discipline.find_by_name(value) || Discipline.find_by_short_name(value)
        if discipline.blank? && value.present?
          discipline = Discipline.create(name: value)
        end
        tournament.discipline_id = discipline.andand.id || Discipline.find_by_name("-").id
      else
        tournament.update_attribute(mappings[label], value)
      end
    end
    # Setzliste
    seedings_prev = tournament.seedings
    tournament.seedings = []
    table = doc.css("#tabs-3 .matchday_table")[0]
    if table.present?
      player = nil
      states = %w{FG NG ENA UNA DIS}
      state_ix = 0
      seeding = nil
      table.css("td").each do |td|
        if td.css("div").present?
          lastname, firstname, club_str = td.css("div").text.strip.match(/(.*),\s*(.*)\s*\((.*)\)/).to_a[1..-1].map(&:strip)
          club = Club.where(region: region).where("name ilike ?", club_str).first ||
              Club.where(region: region).where("shortname ilike ?", club_str).first
          club
          if club.present?
            season_participations = SeasonParticipation.joins(:player).joins(:club).joins(:season).where(seasons: {id: season.id}, players: {firstname: firstname, lastname: lastname})
            if season_participations.count == 1
              season_participation = season_participations.first
              player = season_participation.player
              if season_participation.club_id == club.id
                seeding = Seeding.find_by_player_id_and_tournament_id(player.id, tournament.id) ||
                    Seeding.create(player_id: player.id, tournament_id: tournament.id)
                state_ix = 0
              else
                real_club = season_participations.first.club
                logger.info "[scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} not active in Club #{club_str} [#{club.ba_id}], Region #{region.shortname}, season #{season.name}!"
                logger.info "[scrape_tournaments] Inkonsistence - Fixed: Player #{lastname}, #{firstname} is active in Club #{real_club.shortname} [#{real_club.ba_id}], Region #{real_club.region.shortname}, season #{season.name}!"
                sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player.id, season.id, real_club.id) ||
                    SeasonParticipation.create(player_id: player.id, season_id: season.id, club_id: real_club.id)
                seeding = Seeding.find_by_player_id_and_tournament_id(player.id, tournament.id) ||
                    Seeding.create(player_id: player.id, tournament_id: tournament.id)
                state_ix = 0
              end
            elsif season_participations.count == 0
              players = Player.where(firstname: firstname, lastname: lastname)
              if players.count == 0
                logger.info "[scrape_tournaments] Inkonsistence - Fatal: Player #{lastname}, #{firstname} not found in club #{club_str} [#{club.ba_id}] , Region #{region.shortname}, season #{season.name}! Not found anywhere - typo?"
                logger.info "[scrape_tournaments] Inkonsistence - fixed - added Player Player #{lastname}, #{firstname} active to club #{club_str} [#{club.ba_id}] , Region #{region.shortname}, season #{season.name}"
                player_fixed = Player.create(lastname: lastname, firstname: firstname, club_id: club.id)
                player_fixed.update_attributes(ba_id: 999000000 + player_fixed.id)
                SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, club.id) ||
                    SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
                seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, tournament.id) ||
                    Seeding.create(player_id: player_fixed.id, tournament_id: tournament.id)
                state_ix = 0
              elsif players.count == 1
                player_fixed = players.first
                logger.info "[scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} is not active in Club #{club_str} [#{club.ba_id}], region #{region.shortname} and season #{season.name}"
                SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, club.id) ||
                    SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
                logger.info "[scrape_tournaments] Inkonsistence - fixed: Player #{lastname}, #{firstname} set active in Club #{club_str} [#{club.ba_id}], region #{region.shortname} and season #{season.name}"
                seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, tournament.id) ||
                    Seeding.create(player_id: player_fixed.id, tournament_id: tournament.id)
                state_ix = 0
              elsif players.count > 1
                logger.info "[scrape_tournaments] Inkonsistence - Fatal: Ambiguous: Player #{lastname}, #{firstname} not active everywhere but exists in Clubs [#{players.map(&:club).map { |c| "#{c.shortname} [#{c.ba_id}]" }}] "
                logger.info "[scrape_tournaments] Inkonsistence - temporary fix: Assume Player #{lastname}, #{firstname} is active in Clubs [#{players.map(&:club).map { |c| "#{c.shortname} [#{c.ba_id}]" }.first}] "
                player_fixed = players.first
                SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, club.id) ||
                    SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
                seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, tournament.id) ||
                    Seeding.create(player_id: player_fixed.id, tournament_id: tournament.id)
                state_ix = 0
              end
            else
              #(ambiguous clubs)
              if season_participations.map(&:club_id).uniq.include?(club.id)
                season_participation = season_participations.where(club_id: club.id).first
                player = season_participation.player
                seeding = Seeding.find_by_player_id_and_tournament_id(player.id, tournament.id) ||
                    Seeding.create(player_id: player.id, tournament_id: tournament.id)
                state_ix = 0
              else
                logger.info "[scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} is not active in Club[#{club.ba_id}] #{club_str}, region #{region.shortname} and season #{season.name}"
                fixed_season_participation = season_participations.last
                fixed_club = fixed_season_participation.club
                fixed_player = fixed_season_participation.player
                logger.info "[scrape_tournaments] Inkonsistence - fixed: Player #{lastname}, #{firstname} playing for Club[#{fixed_club.ba_id}] #{fixed_club.shortname}, region #{fixed_club.region.shortname} and season #{season.name}"
                SeasonParticipation.find_by_player_id_and_season_id_and_club_id(fixed_player.id, season.id, fixed_club.id) ||
                    SeasonParticipation.create(player_id: fixed_player.id, season_id: season.id, club_id: fixed_club.id)
                seeding = Seeding.find_by_player_id_and_tournament_id(fixed_player.id, tournament.id) ||
                    Seeding.create(player_id: fixed_player.id, tournament_id: tournament.id)
                state_ix = 0
              end
            end
          else
            logger.info "[scrape_tournaments] Inkonsistence - fatal: Club #{club_str}, region #{region.shortname} not found!! Typo?"
            fixed_club = region.clubs.create(name: club_str, shortname: club_str)
            fixed_player = fixed_club.players.create(firstname: firstname, lastname: lastname)
            fixed_club.update_attributes(ba_id: 999000000 + fixed_club.id)
            fixed_player.update_attributes(ba_id: 999000000 + fixed_player.id)
            SeasonParticipation.create(player_id: fixed_player.id, season_id: season.id, club_id: fixed_club.id)

            logger.info "[scrape_tournaments] Inkonsistence - temporary fix: Club #{club_str} created in region #{region.shortname}"
            logger.info "[scrape_tournaments] Inkonsistence - temporary fix: Player #{lastname}, #{firstname} playing for Club #{club_str}"
            seeding = Seeding.find_by_player_id_and_tournament_id(fixed_player.id, tournament.id) ||
                Seeding.create(player_id: fixed_player.id, tournament_id: tournament.id)
            state_ix = 0
          end
        else
          if td.text.strip =~ /X/
            if seeding.present?
              seeding.update_attribute(:status, states[state_ix])
            else
              logger.info "[scrape_tournaments] Fatal 501 - seeding nil???"
              Kernel.exit(501)
            end
          end
          state_ix += 1
        end
      end
    else
      table
    end

    no_show_ups = seedings_prev - tournament.seedings
    no_show_ups.each do |seeding|
      seeding.status = "UNA"
    end

    # Results
    tournament.games = []
    table = doc.css("#tabs-2 .matchday_table")[0]
    keys = table.css("tr th div").map(&:text).map { |s| s.split("\n").first }
    table.css("tr").each do |row|
      game = nil
      remarks = {}
      row.css("td").each_with_index do |f, ix|
        remarks[keys[ix]] = f.text.strip
        if keys[ix] == "#"
          seqno = f.text.strip.to_i
          game = Game.find_by_seqno_and_tournament_id(seqno, tournament.id) || Game.new(tournament_id: tournament.id, seqno: seqno)
        end
      end
      if game.andand.seqno.present?
        game.gname = remarks["Gr."]
        game.remarks = remarks
        game.save!
        Game.fix_participation(game)
      end
    end

    # Rankings
    groups = doc.css("#tabs-1 fieldset legend").map(&:text).map { |s| s.split("\n").first }
    seedings_hash = tournament.seedings.includes(:player).inject({}) do |memo, seeding|
      memo["#{seeding.player.lastname}, #{seeding.player.firstname}"] = seeding
      memo
    end
    result = {}
    group_results = {}
    doc.css("#tabs-1 fieldset table").each_with_index do |table, ix|
      group = groups[ix]
      keys = table.css("tr th").map(&:text).map { |s| s.split("\n").first }
      table.css("tr").each do |row|
        result_row = {}
        row.css("td").each_with_index do |f, ix|
          result_row[keys[ix]] = f.text.strip
        end
        if result_row.present?
          group_results[group] ||= {}
          group_results[group][result_row["Name"]] = result_row
          result[result_row["Name"]] ||= {}
          result[result_row["Name"]][group] = result_row
        end
      end
    end
    group_results_ranked = {}
    groups.each do |group|
      group_results_ranked[group] = Hash[group_results[group].to_a.sort_by { |a| -(a[1]["Punkte"].to_i * 10000.0 + a[1]["GD"].to_f) }]
      group_results_ranked[group].keys.each_with_index do |name, ix|
        group_results_ranked[group][name]["Rank"] = ix + 1
        result[name][group] = group_results_ranked[group][name]
      end
    end
    seedings_hash.each do |name, seeding|
      remarks = seeding.remarks || {}
      remarks["result"] = result[name]
      seeding.remarks_will_change!
      seeding.remarks = remarks
      seeding.save!
    end
  else
    table
  end

end

