# frozen_string_literal: true

require "#{Rails.root}/app/helpers/application_helper"
require "signet/oauth_2/client"
require "google-apis-calendar_v3"

require "csv"

DE_DISCIPLINE_NAMES = ["Pool", "Snooker", "Kegel", "5 Kegel", "Karambol großes Billard", "Karambol kleines Billard",
                       "Biathlon"].freeze
DISCIPLINE_NAMES = ["Pool", "Snooker", "Pin Billards", "5-Pin Billards", "Carambol Match Billard",
                    "Carambol Small Billard", "Biathlon"].freeze

TABLE_KINDS = ["Pool", "Snooker", "Small Billard", "Half Match Billard", "Match Billard"].freeze

TABLE_KIND_DISCIPLINE_NAMES = {
  "Pin Billards" => [],
  "Biathlon" => [],
  "5-Pin Billards" => [],
  "Pool" => ["9-Ball", "8-Ball", "14.1 endlos", "Blackball"],
  "Small Billard" => ["Dreiband klein", "Freie Partie klein", "Einband klein", "Cadre 52/2", "Cadre 35/2", "Biathlon",
                      "Nordcup", "Petit/Grand Prix"],
  "Match Billard" => ["Dreiband groß", "Einband groß", "Freie Partie groß", "Cadre 71/2", "Cadre 47/2", "Cadre 47/1"],
  "Half Match Billard" => ["Cadre 38/2", "Cadre 57/2"]
}.freeze

namespace :carambus do
  include ApplicationHelper

  desc "check consistency of database"
  task check_consitency: :environment do
    # check for multiple locations with same address
    double_addresses = Location.select("address", "split_part(address, ',', 1)",
                                       "count(*)").group("address, split_part(address, ',', 1)").having("COUNT(*) > 1").to_a.map(&:address)
    puts "ERROR CONSISTENCY: double_addresses:\n#{double_addresses.inspect}" unless double_addresses.blank?
    # check for Locations used by more than one Club (ClubLocations)
    heavy_used_locations = Location.joins(:club_locations)
                                   .group("locations.id")
                                   .having("COUNT(club_locations.club_id) > 1")
    puts "WARNING: Locations used by more than one Club:\n#{heavy_used_locations.map { |l|
      [l.id, l.address, l.clubs.map { |c|
        [c.id, c.shortname]
      }]
    }}" if heavy_used_locations.any?(Location)
    # check for synonyms used at several clubs
    synonyms = []
    h = nil
    Club.all.each do |c|
      c.synonyms.split("\n").each do |s|
        if synonyms.include? s
          puts "WARNING: synonym used for multiple clubs" unless h
          puts c.id, s, c.name
          h = true
        else
          synonyms << s
        end
      end
    end
  end

  desc "delete not conforming events"
  task delete_non_conforming_calendar_entries: :environment do
    location ||= Location[Rails.application.credentials[:location_id]]
    google_creds_json = {
      type: "service_account",
      project_id: "carambus-test",
      private_key_id: Rails.application.credentials.dig(:google_service, :public_key),
      private_key: Rails.application.credentials.dig(:google_service, :private_key).gsub('\n', "\n"),
      client_email: "service-test@carambus-test.iam.gserviceaccount.com",
      client_id: "110923757328591064447",
      auth_uri: "https://accounts.google.com/o/oauth2/auth",
      token_uri: "https://oauth2.googleapis.com/token",
      auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
      client_x509_cert_url: "https://www.googleapis.com/robot/v1/metadata/x509/service-test%40carambus-test.iam.gserviceaccount.com",
      universe_domain: "googleapis.com"
    }.to_json
    scopes = ['https://www.googleapis.com/auth/calendar', 'https://www.googleapis.com/auth/calendar.events']
    authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(google_creds_json),
      scope: scopes
    )
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = authorizer
    calendar_id = Rails.application.credentials[:location_calendar_id]
    response = service.list_events(calendar_id,
                                   max_results: 40,
                                   single_events: true,
                                   order_by: "startTime",
                                   time_min: DateTime.now)
    Array(response&.items).each do |event|
      # allow info entries (word followd by colon)
      next if event.summary.match(/\A\w+\s*:/)

      # allow correct reservations
      title = event.summary
      next if CalendarEvent.tables_from_summary(title, location).present?

      # delete event
      response = remove_event(service, calendar_id, event)
    end
  end

  desc "Check Reservations via Google Calendar 'BC Wedel'"
  task check_reservations: :environment do
    tables_to_be_heated_all = []
    location ||= Location[Rails.application.credentials[:location_id]]
    tables = location.tables.order(:name).to_a
    google_creds_json = {
      type: "service_account",
      project_id: "carambus-test",
      private_key_id: Rails.application.credentials.dig(:google_service, :public_key),
      private_key: Rails.application.credentials.dig(:google_service, :private_key).gsub('\n', "\n"),
      client_email: "service-test@carambus-test.iam.gserviceaccount.com",
      client_id: "110923757328591064447",
      auth_uri: "https://accounts.google.com/o/oauth2/auth",
      token_uri: "https://oauth2.googleapis.com/token",
      auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
      client_x509_cert_url: "https://www.googleapis.com/robot/v1/metadata/x509/service-test%40carambus-test.iam.gserviceaccount.com",
      universe_domain: "googleapis.com"
    }.to_json
    scopes = ['https://www.googleapis.com/auth/calendar', 'https://www.googleapis.com/auth/calendar.events']
    authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(google_creds_json),
      scope: scopes
    )
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = authorizer
    calendar_id = Rails.application.credentials[:location_calendar_id]
    response = service.list_events(calendar_id,
                                   max_results: 40,
                                   single_events: true,
                                   order_by: "startTime",
                                   time_min: DateTime.now)
    puts I18n.l(DateTime.now.utc.in_time_zone("Berlin")), I18n.t("calendar.upcoming")
    puts I18n.t("calendar.no_upcoming") if response&.items&.empty?
    upcoming_events = []
    upcoming_events_h = {}
    summaries = []
    event_ids = []
    Array(response&.items).each do |event|
      event_ids << event.id
      title = event.summary
      if event.summary.match(/\A\w+\s*:/)
        next
      else
        tables_to_be_heated = CalendarEvent.tables_from_summary(title, location).select { |t| t.table_kind.name != "Pool" }
        if tables_to_be_heated.present?
          start = event.start.date || event.start.date_time
          ende = event.end.date || event.end.date_time
          summary_day_hour = "#{title}, #{I18n.l(start, format: "%A")} #{start.strftime("%H:%M")}"
          full_entry = "#{title}, #{(I18n.l start).split(", ").join(", ").gsub(" Uhr",
                                                                               "")} - #{(I18n.l ende).split(", ").last}"
          if summaries.include?(summary_day_hour)
            upcoming_events_h[summary_day_hour][1] = "repeated"
          else
            upcoming_events_h[summary_day_hour] = [full_entry, "single"]
            upcoming_events << full_entry
            summaries << summary_day_hour
          end
          unless ((start.to_i - DateTime.now.to_i) / 1.hour) < 3 &&
            (ende.to_i - DateTime.now.to_i).positive?
            next
          end

          tables_to_be_heated.map { |t| t.check_heater_on(event) }
          tables_to_be_heated_all |= tables_to_be_heated
        else
          remove_event(service, calendar_id, event)
        end
      end
      #
      # t.check_heater_on(event): start heater when event starts within pre_heating_time_in_hours hours
      #   when event already underway but no activity on scoreboard for 1 hour - heater_off!
      # t.check_heater_off:
      #   when no activity on scoreboard for 1 hour - heater_off!
      # (assumes T1 .. Tn responds to the name ordered list of location tables)
    end

    # (tables - tables_to_be_heated_all).map(&:check_heater_off)
    tables.map { |t| t.check_heater_off(event_ids: event_ids) }
    tables.map(&:terminate_outworn_game)
    table_status = JSON.pretty_generate(location.tables_status)
    upcoming_events_with_repeat = []
    upcoming_events.each do |str|
      upcoming_events_h.each_value do |v|
        if v[0] == str
          upcoming_events_with_repeat << "#{str}#{" (...)" if v[1] == "repeated"}"
        end
      end
    end
    events = JSON.pretty_generate(upcoming_events_with_repeat)
    File.write(File.join(Rails.root, "log", "events"), events)
    puts events
    File.write(File.join(Rails.root, "log", "table_status"), table_status)
    puts table_status
    # puts "Heater On on tables #{tables_to_be_heated_all.map(&:name)}"
    # puts "Heater Off on tables #{(tables - tables_to_be_heated_all).map(&:name)}"
  end

  desc "eliminate location duplicates"
  task eliminate_location_duplicates: :environment do
  end

  desc "read regional player ids"
  task read_regional_player_ids: :environment do
    file = "#{Rails.root}/doc/Export-Mitglieder_2022-05-17_11-29-54.csv"
    cc_ids_todo = Player.where.not(cc_id: nil).map(&:cc_id)
    cc_ids_done = []
    str = File.read(file)
    players = CSV.parse(str, headers: true)
    players&.each do |player_str|
      player_arr = player_str[0].split(";")
      cc_id = player_arr[0].to_i
      ba_id = player_arr[1].to_i
      lastname = player_arr[2]&.strip
      firstname = player_arr[3]&.strip
      player = Player.find_by_ba_id(ba_id)
      if player.present?
        unless player.cc_id == cc_id
          if player.cc_id.blank?
            begin
              player.update(cc_id:)
            rescue
              # ccid already used else were?
              p = Player.find_by_cc_id(cc_id)
              RegionCc.logger.info "REPORT DUPLICATE PROBLEM passno #{cc_id}, #{lastname}, #{firstname} changed dbu-nr from #{p.ba_id} to #{ba_id}!!!"
              next
            end
            RegionCc.logger.info "REPORT UPDATED cc_id: '#{cc_id}' of player #{player.fullname}[#{player.id}]"
          else
            player.update(cc_id:)
            RegionCc.logger.info "REPORT CHANGED!! cc_id from: '#{player.cc_id}' to '#{cc_id}' of player #{player.fullname}[#{player.id}]"
          end
        end
        if player.lastname != lastname
          RegionCc.logger.info "REPORT CHANGED LASTNAME: from '#{player.lastname}' to '#{lastname}'"
          player.update(lastname:)
        end
        if player.firstname != firstname
          RegionCc.logger.info "REPORT CHANGED FIRSTNAME: from '#{player.firstname}' to '#{firstname}'"
          player.update(firstname:)
        end
        cc_ids_done.push(cc_id)
      else
        players = Player.where(firstname:, lastname:).where("ba_id > 999000000")
        if players.count == 1
          player = players.first
          player&.update(cc_id:, ba_id:)
          RegionCc.logger.info "REPORT UPDATED cc_id: '#{cc_id}', ba_id: #{ba_id} of player #{player&.fullname}[#{player&.id}]"
          cc_ids_done.push(cc_id)
        else
          Player.create(firstname:, lastname:, cc_id:, ba_id:)
          RegionCc.logger.info "REPORT CREATED new Player #{player_arr.inspect}"
        end
      end
    end
    RegionCc.logger.info "REPORT some pass-no not used anymore: #{cc_ids_todo - cc_ids_done}"
    RegionCc.logger.info "REPORT some new pass-nos: #{cc_ids_done - cc_ids_todo}"
  end

  desc "update disciplines in party games"
  task update_disciplines_in_party_games: :environment do
    PartyGame.all.each do |pg|
      pg.update_discipline_from_name
      pg.save
    end
  end

  desc "Scrape leagues"
  task scrape_leagues: :environment do
    League.set_scraping(0, nil)
    League.set_scraping(1, nil)
    League.set_scraping(2, true)
    sh_names = %w[BBV NBV BVB BBBV BVNRW DBU HBU]
    Season.order(ba_id: :desc).each do |season|
      Region.where.not(shortname: sh_names).all.each do |region|
        # Region.where(shortname: "BVBW").all.each do |region|
        Rails.logger.info "===== #{region.shortname}"
        League.set_scraping(0, season.id == 7 && region.shortname == "BLVN")

        # TODO: if scraped completely .limit(2)
        if League.scraping[0]
          Rails.logger.info "===== scraping #{region.shortname}"
          League.scrape_leagues_by_region_and_season(region, season, game_details: true, league_details: true)
        end
      end
    end
  end

  desc "Scrape DBU leagues"
  task scrape_dbu_leagues: :environment do
    Season.order(ba_id: :desc).limit(2).each do |season|
      League.scrape_leagues_by_region_and_season(Region.find_by_shortname("DBU"), season)
    end
  end

  desc "Update carambus"
  task update_carambus: :environment do
    Version.update_carambus
  end

  desc "scrape regional club ids"
  task scrape_regional_club_ids: :environment do
    url = "https://ndbv.club-cloud.de/verein-details.php?p=20-----1-100000-0"
    Rails.logger.info "reading index page - to scrape regional club ids"
    uri = URI(url)
    html = Net::HTTP.get(uri)
    doc = Nokogiri::HTML(html)
    clubs = doc.css("article .cc_bluelink")
    clubs.each do |club|
      url = club.attribute("href").value
      params = url.match(/.*p=(.*)/).andand[1].split("-|")
      club_title = club.text
      c = Club.where(region_id: 1, shortname: club_title).first
      c.update(cc_id: params[3].to_i) if c.present?
    end
  end

  desc "create countries"
  task create_countries: :environment do
  end

  desc "list of scaffolds"
  task "list_scaffolds" => :environment do
    arr = Module.constants.select do |constant_name|
      constant = eval constant_name.to_s
      constant if !constant.nil? && constant.is_a?(Class) && (constant.superclass == ActiveRecord::Base)
    end
    puts arr.inspect
  end

  desc "retrieve updates from API server"
  task retrieve_updates: :environment do
    args = Carambus.config.context.present? ? {
      region_id: Region.find_by_shortname(Carambus.config.context)&.id
    } : {}
    (1..10).each.map { |i| Version.update_from_carambus_api(args) }
  end

  desc "Init Disciplines"
  task init_disciplines: :environment do
    TABLE_KIND_DISCIPLINE_NAMES.each do |tk_name, v|
      tk = TableKind.find_by_name(tk_name) || TableKind.create(name: tk_name)
      v.each do |dis_name|
        Discipline.find_by_name_and_table_kind_id(dis_name, tk.id) ||
          Discipline.create(name: dis_name, table_kind_id: tk.id)
      end
    end
  end

  desc "update disciplines in party games"
  task update_disciplines_in_party_games: :environment do
    PartyGame.all.each do |pg|
      pg.update_discipline_from_name
      pg.save
    end
  end

  desc "fix tournament discipline by name"
  task fix_tournament_discipline_by_name: :environment do
    unknown_discipline = Discipline.find_by_name("-")
    Tournament.where(discipline_id: unknown_discipline.id).all.each do |tournament|
      Tournament::NAME_DISCIPLINE_MAPPINGS.each do |k, v|
        tournament.update(discipline_id: Discipline.find_by_name(v).id) if /#{k}/.match?(tournament.title)
      end
    end
  end

  desc "update tournament_plan executor_params"
  # TODO: TournamentPlans should be generated from readable Version in TournamentPlan Model
  task update_executor_params: :environment do
    TournamentPlan.update_executor_params
  end

  desc "Scrape Tournaments"
  task scrape_tournaments: :environment do
    Season.order(name: :desc).to_a[0..1]&.each do |season|
      if season.name >= "2021/2022"
        season.scrape_single_tournaments_public_cc
      end
    end
  end

  desc "Init PlayerClass"
  task init_player_classes: :environment do
  end

  desc "remove duplicate season participations"
  task remove_duplicate_season_participations: :environment do
    grouped = SeasonParticipation.all.group_by { |s| [s.player_id, s.club_id, s.season_id] }
    grouped.each_value do |duplicates|
      duplicates.shift
      duplicates.each(&:destroy)
    end
  end

  desc "update tournaments"
  task update_tournaments: :environment do
    opts = get_base_opts_from_environment
    env_season_name = ENV["SEASON"].presence || opts[:season_name]
    env_region_shortname = ENV["REGION"] || opts[:context].upcase
    seasons = Season.order(ba_id: :desc).to_a
    if env_season_name.present?
      season = Season.find_by(name: env_season_name)
      if season.blank?
        Rails.logger.info "Error: Unknown Season: #{env_season_name}"
        raise StandardError, "Unknown Season: #{env_season_name}"
      end
      seasons = [season]
    end

    seasons.each do |seasonx|
      region = Region.find_by(shortname: env_region_shortname)
      region_cc = region.region_cc
      if seasonx.name > Season::MAX_BA_SEASON
        # scrape ClubCloud
        next if env_region_shortname.present? && region.shortname != env_region_shortname

        url = region.public_cc_url_base
        unless url.present? && region_cc.present?
          msg = "Error: Cannot scrape - Region[#{region.id}] not configured for ClubCloud"
          Rails.logger.error msg
          raise StandardError, msg
        end
        args = {
          f: region_cc.cc_id,
          s: seasonx.name,
          eps: 100_000
        }
        _, doc = region_cc.post_cc_public("sb_meisterschaft", args, opts)
        table = doc.css("article .silver")[1]
        lines = table.css("tr")
        lines.each do |tr|
          next if tr.css("td").blank?

          tds = tr.css("td")
          # date = Date.parse(tds[1].text)
          branch_cc = BranchCc.find_by(name: tds[3].text.strip)
          # title = tds[2].css("a").text
          link = tds[2].css("a")[0]["href"]
          params = link.match(/p=(.*)/)[1].split("-")
          if params[0].to_i != region_cc.cc_id || params[2] != seasonx.name
            msg = "Error: received unexpected result params=#{params.inspect}"
            Rails.logger.error msg
            raise StandardError, msg
          end
          cc_id = params[3].to_i
          tournament_cc = TournamentCc.find_or_initialize_by(cc_id:, season: seasonx.name, branch_cc:)
          tournament_cc.update(cc_id:)
          # if tournament_cc.new_record?
          # tournament_cc.update_from_cc(opts)
          # end
        end
      end
    end
  end

  desc "create local seed"
  task create_local_seed: :environment do
    output = []
    void_keys = { "User" => ["terms_of_service"]}
    _table_max_ids, local_tables = Version.max_ids
    local_tables.each do |classz|
      output.push("#{classz.underscore}_id_map = {}")
      case classz
      when "TournamentMonitor\n"
        output.push("#+++TournamentMonitor+++")
        output.push("#---Tournament---")
        output.push("h1 = JSON.pretty_generate(tournament_id_map)")
      when "Game"
        output.push("#---Tournament---")
        output.push("h1 = JSON.pretty_generate(tournament_id_map)")
      when "table"
        output.push("#---Location---")
        output.push("h1 = JSON.pretty_generate(location_id_map)")
      when "GameParticipation"
        output.push("#+++GameParticipation+++")
        output.push("#---Player---")
        output.push("h1 = JSON.pretty_generate(player_id_map)")
        output.push("#---Game---")
        output.push("h2 = JSON.pretty_generate(game_id_map)")
      when "Seeding"
        output.push("#+++Seeding+++")
        output.push("#---Tournament---")
        output.push("h1 = JSON.pretty_generate(tournament_id_map)")
        output.push("#---Player---")
        output.push("h2 = JSON.pretty_generate(player_id_map)")
      when "TableMonitor"
        output.push("#+++TableMonitor+++")
        output.push("#---TournamentMonitor---")
        output.push("h1 = JSON.pretty_generate(tournament_monitor_id_map)")
      end
      classz.constantize.where("id >= 50000000").order(:id).all.each do |obj|
        time_keys = %w[date created_at updated_at started_at ended_at accepted_terms_at accepted_privacy_at
                       announcements_read_at invitation_created_at invitation_accepted_at timer_start_at timer_finish_at timer_halt_at trial_ends_at ends_at]
        hash_keys = %w[data roles]
        attrs = obj.serializable_hash.delete_if do |key, _value|
          (hash_keys + time_keys + void_keys[classz].to_a).include?(key)
        end.to_s.gsub(/[{}]/, "")
        time_keys.each do |key|
          if obj.respond_to?(:"#{key}") && obj.send(:"#{key}").present?
            output.push("#{key} = Time.at(#{obj.send(key.to_s).to_f})")
            attrs += ", #{key}: #{key}"
          end
        end
        output.push("obj_was = #{classz.constantize}.where(#{attrs}).first")
        output.push("if obj_was.blank?")
        attrs_no_id = obj.serializable_hash.delete_if do |key, _value|
          (["id"] + hash_keys + time_keys + void_keys[classz].to_a).include?(key)
        end.to_s.gsub(/[{}]/, "")
        output.push("  obj_was = #{classz.constantize}.where(#{attrs_no_id}).first")
        output.push("  if obj_was.blank?")
        output.push("    obj = #{classz.constantize}.new(#{obj.serializable_hash.delete_if do |key, _value|
          (["id"] + hash_keys + time_keys + void_keys[classz].to_a).include?(key)
        end.to_s.gsub(/[{}]/, "")})")
        case classz
        when "TournamentMonitor"
          if obj.tournament_id.present?
            output.push("    obj.tournament_id = tournament_id_map[#{obj.tournament_id}] if tournament_id_map[#{obj.tournament_id}].present?")
          end
        when "Game"
          if obj.tournament_id.present?
            output.push("    obj.tournament_id = tournament_id_map[#{obj.tournament_id}] if tournament_id_map[#{obj.tournament_id}].present?")
          end
        when "GameParticipation"
          if obj.game_id.present?
            output.push("    obj.game_id = game_id_map[#{obj.game_id}] if game_id_map[#{obj.game_id}].present?")
          end
        when "Table"
          if obj.location_id.present?
            output.push("    obj.location_id = location_id_map[#{obj.location_id}] if location_id_map[#{obj.location_id}].present?")
          end
        when "Seeding"
          if obj.tournament_id.present?
            output.push("    obj.tournament_id = tournament_id_map[#{obj.tournament_id}] if tournament_id_map[#{obj.tournament_id}].present?")
          end
          output.push("    obj.player_id = player_id_map[#{obj.player_id}] if player_id_map[#{obj.player_id}].present?")
        when "TableMonitor"
          if obj.tournament_monitor_id.present?
            output.push("    obj.tournament_monitor_id = tournament_monitor_id_map[#{obj.tournament_monitor_id}] if tournament_monitor_id_map[#{obj.tournament_monitor_id}].present?")
          end
          if obj.game_id.present?
            output.push("    obj.game_id = game_id_map[#{obj.id}] if game_id_map[#{obj.game_id}].present?")
          end
        when "User"
          output.push('    obj.password = "******"')
          output.push("    obj.terms_of_service = true")
        end
        hash_keys.each do |key|
          if obj.respond_to?(:"#{key}") && obj.send(:"#{key}").present?
            output.push("    #{key} = #{obj.send(key.to_s).inspect}")
            output.push("    obj.#{key} = #{key}")
          end
        end
        time_keys.each do |key|
          if obj.respond_to?(:"#{key}") && obj.send(:"#{key}").present?
            output.push("    #{key} = Time.at(#{obj.send(key.to_s).to_f})")
          end
        end
        output.push("    begin")
        output.push("      obj.save!")
        output.push("      obj.update_column(:encrypted_password, \"#{obj.encrypted_password}\")") if classz == "User"
        output.push("      id = obj.id")
        output.push("      #{classz.underscore}_id_map[#{obj.id}] = id")
        time_keys.each do |key|
          if obj.respond_to?(:"#{key}") && obj.send(:"#{key}").present?
            output.push("      obj.update_column(:\"#{key}\", #{key})")
          end
        end
        output.push("    rescue StandardError => e")
        output.push("    end")
        output.push("  else")

        output.push("    id = obj_was.id")
        output.push("    #{classz.underscore}_id_map[#{obj.id}] = id")

        output.push("  end")
        output.push("end")
      end
    end
    f = File.new("#{Rails.root}/db/seeds.rb", "w")
    f.write(output.join("\n"))
    f.close
  end

  desc "filter local changes from sql dump"
  task filter_local_changes_from_sql_dump: :environment do
    config = YAML.load_file("#{Rails.root}/config/database.yml")
    database = config[Rails.env]["database"]
    unless ENV["SKIP_PG_DUMP"].present?
      puts "======== make a pg_dump of #{database} =========="
      # Ensure local extension tables use the local ID range before extracting delta
      # This shifts IDs for table_locals and tournament_locals where needed and resets their sequences
      bump_sql = <<~SQL
        BEGIN;
        UPDATE public.table_locals SET id = id + 50000000 WHERE id < 50000000;
        UPDATE public.tournament_locals SET id = id + 50000000 WHERE id < 50000000;
        SELECT setval(pg_get_serial_sequence('public.table_locals','id'), GREATEST(1, (SELECT COALESCE(MAX(id),1) FROM public.table_locals)), true);
        SELECT setval(pg_get_serial_sequence('public.tournament_locals','id'), GREATEST(1, (SELECT COALESCE(MAX(id),1) FROM public.tournament_locals)), true);
        COMMIT;
      SQL
      system(%Q(psql #{database} -v ON_ERROR_STOP=1 -c "#{bump_sql.gsub("\n"," ").gsub('"','\\\"')}"))
      `pg_dump #{"-Uwww_data" if Rails.env == "production"} #{database} > #{Rails.root}/#{database}.sql`
    end
    in_copy_users_or_tournaments = false
    priority_tables = []
    File.open("#{Rails.root}/#{database}.sql", "r").each_line do |line|
      if /^COPY/.match?(line)
        in_copy_users_or_tournaments = case line
                                       when /^COPY public.users /
                                         true
                                       when /^COPY public.tournaments /
                                         true
                                       else
                                         false
                                       end
        priority_tables.push line if in_copy_users_or_tournaments
      elsif /^\\\./.match?(line)
        if in_copy_users_or_tournaments
          priority_tables.push line
          in_copy_users_or_tournaments = false
        end
      elsif in_copy_users_or_tournaments
        priority_tables.push line if line.match(/^(\d+)\t/).andand[1].to_i > Setting::MIN_ID
      end
    end

    f = File.new("#{Rails.root}/#{database}_50000000.sql", "w")
    first_copy = true
    in_copy_mode = false
    File.open("#{Rails.root}/#{database}.sql", "r").each_line do |line|
      if /^COPY/.match?(line)
        in_copy_mode = true
        if first_copy
          f.write("#{priority_tables.join("")}\n")
          first_copy = false
        end
        in_copy_users_or_tournaments = case line
                                       when /^COPY public.users /
                                         true
                                       when /^COPY public.tournaments /
                                         true
                                       else
                                         false
                                       end
        f.puts line unless in_copy_users_or_tournaments
      elsif /^\\\./.match?(line)
        in_copy_mode = false
        f.puts line unless in_copy_users_or_tournaments
      elsif in_copy_mode
        f.puts line if !in_copy_users_or_tournaments && line.match(/^(\d+)\t/).andand[1].to_i > Setting::MIN_ID
      else
        f.puts line
      end
    end
    f.close
  end

  desc "filter local changes from sql dump new"
  task filter_local_changes_from_sql_dump_new: :environment do
    database = ENV["DATABASE"]
    in_copy_users_or_tournaments = false
    priority_tables = []
    # Ensure local extension tables use the local ID range before extracting delta
    bump_sql = <<~SQL
      BEGIN;
      UPDATE public.table_locals SET id = id + 50000000 WHERE id < 50000000;
      UPDATE public.tournament_locals SET id = id + 50000000 WHERE id < 50000000;
      SELECT setval(pg_get_serial_sequence('public.table_locals','id'), GREATEST(1, (SELECT COALESCE(MAX(id),1) FROM public.table_locals)), true);
      SELECT setval(pg_get_serial_sequence('public.tournament_locals','id'), GREATEST(1, (SELECT COALESCE(MAX(id),1) FROM public.tournament_locals)), true);
      COMMIT;
    SQL
    system(%Q(psql #{database} -v ON_ERROR_STOP=1 -c "#{bump_sql.gsub("\n"," ").gsub('"','\\\"')}"))
    File.open("#{Rails.root}/#{database}.sql", "r").each_line do |line|
      if /^COPY/.match?(line)
        in_copy_users_or_tournaments = case line
                                       when /^COPY public.users /
                                         true
                                       when /^COPY public.tournaments /
                                         true
                                       else
                                         false
                                       end
        priority_tables.push line if in_copy_users_or_tournaments
      elsif /^\\\./.match?(line)
        if in_copy_users_or_tournaments
          priority_tables.push line
          in_copy_users_or_tournaments = false
        end
      elsif in_copy_users_or_tournaments
        priority_tables.push line if line.match(/^(\d+)\t/).andand[1].to_i > Setting::MIN_ID
      end
    end

    f = File.new("#{Rails.root}/#{database}_50000000.sql", "w")
    first_copy = true
    in_copy_mode = false
    File.open("#{Rails.root}/#{database}.sql", "r").each_line do |line|
      if /^COPY/.match?(line)
        in_copy_mode = true
        if first_copy
          f.write("#{priority_tables.join("")}\n")
          first_copy = false
        end
        in_copy_users_or_tournaments = case line
                                       when /^COPY public.users /
                                         true
                                       when /^COPY public.tournaments /
                                         true
                                       else
                                         false
                                       end
        f.puts line unless in_copy_users_or_tournaments
      elsif /^\\\./.match?(line)
        in_copy_mode = false
        f.puts line unless in_copy_users_or_tournaments
      elsif in_copy_mode
        f.puts line if !in_copy_users_or_tournaments && line.match(/^(\d+)\t/).andand[1].to_i > Setting::MIN_ID
      else
        f.puts line
      end
    end
    f.close
  end

  desc "fix game participations"
  task fix_game_participations: :environment do
    # Game.all.each do |game|
    #   Game.fix_participation(game)
    # end
    Game.all.each do |game|
      gname = game.data["Gr."]
      game.update(gname:) if gname.present?
    end
    # Game.fix_participation(Game[42855])
  end

  desc "update ranking tables"
  task update_ranking_tables: :environment do
    # for all seasons - starting with earliest
    # season_from = ENV["SEASON_FROM"] ||= Season.order(name: :desc).to_a[2]&.name
    # Season.order(ba_id: :asc).where("name >= ?", season_from).each do |season|
    Season.order(id: :asc).each do |season|
      # for all regions
      # TEST
      #next unless season.name == "2024/2025"

      Region.where(shortname: Region::SHORTNAMES_CARAMBUS_USERS + Region::SHORTNAMES_OTHERS).all.each do |region|
        # for all disciplines
        # TEST
        #next unless region.shortname == "NBV"

        Discipline.all.each do |discipline|
          # for all relevant tournaments
          # TEST
          next unless discipline.root.name == "Karambol"

          players = {}
          Tournament.where(season: season, organizer_type: "Region", organizer_id: region.id,
                           discipline: discipline).each do |tournament|
            # for all participants

            sum_keys = %w[Sp.G Sp.V G V Bälle Aufn Punkte Frames Partiepunkte Satzpunkte Kegel]
            max_keys = %w[Sp.Quote Quote GD HB HS HGD BED]
            float_keys = %w[GD HGD BED]
            # ignore_keys = %w{# Name Verein Rank}
            # computes = %w{GD:Bälle/Aufn Quote:100*G/V Sp.Quote:100*Sp.G/Sp.V}
            tournament.seedings.includes(:player).each do |seeding|
              player_record = players[seeding.player.id]
              gl = seeding.data.andand["result"].andand["Gesamtrangliste"] || {}
              if gl["Aufn."].present?
                gl["Aufn"] = gl.delete("Aufn.")
              end
              if gl["Bälle"].blank?
                gl["Bälle"] = gl.delete("Punkte")
              end
              unless player_record.present?
                players[seeding.player.id] = {}
                ((max_keys | sum_keys) & gl.keys).each do |k|
                  players[seeding.player.id][k] = 0
                end
                players[seeding.player.id]["t_ids"] = []
              end
              players[seeding.player.id]["t_ids"] << tournament.id
              (sum_keys & gl.keys).each do |k|
                players[seeding.player.id][k] = (players[seeding.player.id][k] || 0) + gl[k].presence.to_i
              end
              (max_keys & gl.keys).each do |k|
                v = gl[k]
                case v
                when /%/
                  vf = v.gsub(/\s*%/, "").tr(",", ".").to_f
                  pf = players[seeding.player.id][k] || 0
                  players[seeding.player.id][k] = [vf, pf].max
                when /,/
                  vf = v.tr(",", ".").to_f
                  pf = players[seeding.player.id][k] || 0
                  players[seeding.player.id][k] = [vf, pf].max
                else
                  vi = v.is_a?(Float) ? v : v.to_i
                  pi = players[seeding.player.id][k] || 0
                  players[seeding.player.id][k] = [vi, pi].max
                end
              end
            end
          rescue => e
            e
          end
          players.keys.select do |player_id|
            values = players[player_id]
            values["Bälle"].to_f.positive? && values["Aufn"].to_f.positive?
          end.sort_by do |player_id|
            values = players[player_id]
            100.0 * values["Bälle"].to_f / values["Aufn"].to_f
            # values['GD'].to_f
          end.reverse
                 .each_with_index do |player_id, ix|
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
            values.each_key do |k|
              mapped_k = PlayerRanking::KEY_MAPPINGS[k]
              attributes[mapped_k] = values[k]
            end
            attributes[:remarks] = data
            attributes[:rank] = ix + 1
            attributes[:gd] = attributes[:balls].to_f / attributes[:innings].to_f if attributes[:innings].present?
            player_ranking.update(attributes)
          end
        end
      end
    end
  rescue => e
    e
  end

  desc "generate locations"
  task generate_locations: :environment do
    Tournament.includes(:organizer, :region).order("tournaments.ba_id asc").each do |t|
      @location = nil
      @organizer = t.organizer || t.region
      @address_a = t.location.andand.split("\n").andand.map(&:strip)
      if @address_a.present?
        @name = @address_a.shift
        @address = @address_a.join("\n")
        @location = Location.where(name: @name, address: @address, organizer: @organizer).first_or_create!
      end
      t.location = @location
      t.save!
    end
  end
  desc "scrape new tournaments"
  task scrape_new_tournaments: :environment do
    itest = Tournament.where.not(ba_id: nil).order("tournaments.ba_id desc").first&.ba_id
    ip = 14
    url = "https://nbv.billardarea.de"
    dir = 1
    while ip >= 0
      itest += dir * 2 ** ip
      url_tournament = "/cms_single/show/#{itest}"
      uri = URI(url + url_tournament)
      res = Net::HTTP.post_form(uri, "data[Season][check]" => "87gdsjk8734tkfdl",
                                "data[Season][season_id]" => Season.last.ba_id.to_s)
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
    range = (Tournament.where.not(ba_id: nil).order("tournaments.ba_id desc").first&.ba_id.to_i..(itest - 1))
    Season.last.scrape_tournaments(range.to_a)
  end

  desc "copy season participations to next season"
  task copy_season_participations_to_next_season: :environment do
    Season.current_season.copy_season_participations_to_next_season
  end

  desc "Reconstruct GamePlans from existing data for a specific season"
  task :reconstruct_game_plans, [:season_name, :region_shortname, :discipline] => :environment do |t, args|
    season_name = args[:season_name]
    region_shortname = args[:region_shortname]
    discipline = args[:discipline]
    
    if season_name.blank?
      puts "Usage: rake carambus:reconstruct_game_plans[season_name,region_shortname,discipline]"
      puts "Examples:"
      puts "  rake carambus:reconstruct_game_plans[2021/2022]"
      puts "  rake carambus:reconstruct_game_plans[2021/2022,BBV]"
      puts "  rake carambus:reconstruct_game_plans[2021/2022,BBV,Pool]"
      puts "  rake carambus:reconstruct_game_plans[2021/2022,,Pool]"
      puts ""
      puts "Disciplines: Pool, Karambol, Snooker, Kegel"
      exit 1
    end
    
    season = Season.find_by_name(season_name)
    if season.blank?
      puts "Season '#{season_name}' not found"
      exit 1
    end
    
    opts = {}
    opts[:region_shortname] = region_shortname if region_shortname.present?
    opts[:discipline] = discipline if discipline.present?
    
    filter_description = []
    filter_description << "region: #{region_shortname}" if region_shortname.present?
    filter_description << "discipline: #{discipline}" if discipline.present?
    filter_text = filter_description.any? ? " (#{filter_description.join(', ')})" : ""
    
    puts "Starting GamePlan reconstruction for season: #{season_name}#{filter_text}"
    results = League.reconstruct_game_plans_for_season(season, opts)
    
    puts "\nReconstruction completed:"
    puts "Success: #{results[:success]}"
    puts "Failed: #{results[:failed]}"
    
    if results[:errors].any?
      puts "\nErrors:"
      results[:errors].each { |error| puts "  - #{error}" }
    end
  end

  desc "Reconstruct GamePlan for a specific league"
  task :reconstruct_league_game_plan, [:league_id] => :environment do |t, args|
    league_id = args[:league_id]
    
    if league_id.blank?
      puts "Usage: rake carambus:reconstruct_league_game_plan[league_id]"
      puts "Example: rake carambus:reconstruct_league_game_plan[123]"
      exit 1
    end
    
    league = League.find_by_id(league_id)
    if league.blank?
      puts "League with ID #{league_id} not found"
      exit 1
    end
    
    puts "Reconstructing GamePlan for league: #{league.name} (ID: #{league.id})"
    game_plan = league.reconstruct_game_plan_from_existing_data
    
    if game_plan
      puts "Successfully reconstructed GamePlan: #{game_plan.name} (ID: #{game_plan.id})"
    else
      puts "Failed to reconstruct GamePlan for league: #{league.name}"
      exit 1
    end
  end

  desc "Delete GamePlans for a specific season"
  task :delete_game_plans, [:season_name, :region_shortname, :discipline] => :environment do |t, args|
    season_name = args[:season_name]
    region_shortname = args[:region_shortname]
    discipline = args[:discipline]
    
    if season_name.blank?
      puts "Usage: rake carambus:delete_game_plans[season_name,region_shortname,discipline]"
      puts "Examples:"
      puts "  rake carambus:delete_game_plans[2021/2022]"
      puts "  rake carambus:delete_game_plans[2021/2022,BBV]"
      puts "  rake carambus:delete_game_plans[2021/2022,BBV,Pool]"
      puts "  rake carambus:delete_game_plans[2021/2022,,Pool]"
      puts ""
      puts "Disciplines: Pool, Karambol, Snooker, Kegel"
      exit 1
    end
    
    season = Season.find_by_name(season_name)
    if season.blank?
      puts "Season '#{season_name}' not found"
      exit 1
    end
    
    opts = {}
    opts[:region_shortname] = region_shortname if region_shortname.present?
    opts[:discipline] = discipline if discipline.present?
    
    filter_description = []
    filter_description << "region: #{region_shortname}" if region_shortname.present?
    filter_description << "discipline: #{discipline}" if discipline.present?
    filter_text = filter_description.any? ? " (#{filter_description.join(', ')})" : ""
    
    puts "Deleting GamePlans for season: #{season_name}#{filter_text}"
    deleted_count = League.delete_game_plans_for_season(season, opts)
    puts "Deleted #{deleted_count} GamePlans"
  end

  desc "Clean and reconstruct GamePlans for a specific season"
  task :clean_reconstruct_game_plans, [:season_name, :region_shortname, :discipline] => :environment do |t, args|
    season_name = args[:season_name]
    region_shortname = args[:region_shortname]
    discipline = args[:discipline]
    
    if season_name.blank?
      puts "Usage: rake carambus:clean_reconstruct_game_plans[season_name,region_shortname,discipline]"
      puts "Examples:"
      puts "  rake carambus:clean_reconstruct_game_plans[2021/2022]"
      puts "  rake carambus:clean_reconstruct_game_plans[2021/2022,BBV]"
      puts "  rake carambus:clean_reconstruct_game_plans[2021/2022,BBV,Pool]"
      puts "  rake carambus:clean_reconstruct_game_plans[2021/2022,,Pool]"
      puts ""
      puts "Disciplines: Pool, Karambol, Snooker, Kegel"
      exit 1
    end
    
    season = Season.find_by_name(season_name)
    if season.blank?
      puts "Season '#{season_name}' not found"
      exit 1
    end
    
    opts = {}
    opts[:region_shortname] = region_shortname if region_shortname.present?
    opts[:discipline] = discipline if discipline.present?
    
    filter_description = []
    filter_description << "region: #{region_shortname}" if region_shortname.present?
    filter_description << "discipline: #{discipline}" if discipline.present?
    filter_text = filter_description.any? ? " (#{filter_description.join(', ')})" : ""
    
    puts "Cleaning and reconstructing GamePlans for season: #{season_name}#{filter_text}"
    
    # First delete existing GamePlans
    puts "Step 1: Deleting existing GamePlans..."
    deleted_count = League.delete_game_plans_for_season(season, opts)
    puts "Deleted #{deleted_count} GamePlans"
    
    # Then reconstruct them
    puts "Step 2: Reconstructing GamePlans..."
    results = League.reconstruct_game_plans_for_season(season, opts)
    
    puts "\nReconstruction completed:"
    puts "Success: #{results[:success]}"
    puts "Failed: #{results[:failed]}"
    
    if results[:errors].any?
      puts "\nErrors:"
      results[:errors].each { |error| puts "  - #{error}" }
    end
  end
end

