require 'open-uri'
require 'net/http'
require 'dnssd'

class Tournament < ActiveRecord::Base

  include AASM
  has_paper_trail

  belongs_to :discipline
  belongs_to :region
  belongs_to :season
  belongs_to :tournament_plan
  has_many :seedings, -> { order(position: :asc) }
  has_many :games, dependent: :destroy
  has_one :tournament_monitor
  has_one :setting
  has_many :tournament_tables

  serialize :data, Hash

  aasm column: "state", skip_validation_on_save: true do
    state :new_tournament, initial: true, :after_enter => [:reset_tournament]
    state :accreditation_finished
    state :tournament_seeding_finished
    state :tournament_mode_defined
    state :tournament_started_waiting_for_monitors
    state :tournament_started
    state :tournament_finished
    state :results_published
    state :closed
    before_all_events :before_all_events
    event :finish_seeding do
      transitions from: [:new_tournament, :accreditation_finished, :tournament_seeding_finished], to: :tournament_seeding_finished
    end
    event :finish_mode_selection do
      transitions from: [:tournament_seeding_finished, :tournament_mode_defined], to: :tournament_mode_defined
    end
    event :start_tournament! do
      transitions from: [:tournament_started, :tournament_mode_defined, :tournament_started_waiting_for_monitors], to: :tournament_started_waiting_for_monitors
    end
    event :signal_tournament_monitors_ready do
      transitions from: [:tournament_started, :tournament_mode_defined, :tournament_started_waiting_for_monitors], to: :tournament_started
    end
    event :reset_tournament_monitor do
      transitions to: :new_tournament, guard: :tournament_not_yet_started
    end
    event :forced_reset_tournament_monitor do
      transitions to: :new_tournament
    end
    event :finish_tournament do
      transitions from: :tournament_started, to: :tournament_finished
    end

    event :have_results_published do
      transitions from: :tournament_finished, to: :results_published
    end
  end

  def self.logger
    @@debug_logger ||= Logger.new("#{Rails.root}/log/debug.log")
  end

  NAME_DISCIPLINE_MAPPINGS = {
      "9-Ball" => "9-Ball",
      "8-Ball" => "8-Ball",
      "14.1" => "14.1 endlos",
      "47/2" => "Cadre 47/2",
      "71/2" => "Cadre 71/2",
      "35/2" => "Cadre 35/2",
      "52/2" => "Cadre 52/2",
      "Kl.*I.*Freie" => "Freie Partie groß",
      "Freie.*Kl.*I" => "Freie Partie groß",
      "Einband.*Kl.*I" => "Einband groß",
      ".*Kl.*I.*Einband" => "Einband groß",
      "Einband" => "Einband klein",
      "Freie Partie" => "Freie Partie klein",
  }

  COLUMN_NAMES = {#TODO FILTERS
                  "BA_ID" => "tournaments.ba_id",
                  "BA State" => "tournaments.ba_state",
                  "Title" => "tournaments.title",
                  "Shortname" => "tournaments.shortname",
                  "Discipline" => "disciplines.name",
                  "Region" => "regions.name",
                  "Season" => "seasons.name",
                  "Status" => "tournaments.plan_or_show",
                  "SingleOrLeague" => "tournaments.single_or_league",
  }

  def initialize_tournament_monitor
    logger.info "[initialize_tournament_monitor]..."
    TournamentMonitor.transaction do
      begin
        http = TCPServer.new nil, 80
        DNSSD.announce http, 'carambus server'
        Setting.key_set_val(:carambus_server_status, "ready to accept connections from scoreboards")
        TournamentMonitor.find_or_create_by!(tournament_id: self.id)
        reload
      rescue Exception => e
        logger.info "[initialize_tournament_monitor] Exception #{e}:\n#{e.backtrace.join("\n")}"
        reset_tournament
        Rails.logger.error("Some problem occurred when creating TournamentMonitor - Tournament resetted")
      end

      logger.info "state:#{state}...[initialize_tournament_monitor]"
    end

  end


  def scrape_single_tournament(opts = {})
    self.reset_tournament
    logger = opts[:logger] || Logger.new("#{Rails.root}/log/scrape.log")
    game_details = opts.keys.include?(:game_details) ? opts[:game_details] : true
    season = self.season
    region = self.region
    url = "https://#{region.shortname.downcase}.billardarea.de"
    if self.single_or_league == "single"
      url_tournament = "/cms_#{self.single_or_league}/show/#{self.ba_id}"
      Rails.logger.info "reading #{url + url_tournament} - self \"#{self.title}\" season #{season.name}"
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
          self.date = DateTime.parse(date_begin + "#{" #{time_begin}" if time_begin.present?}")
          self.end_date = DateTime.parse(date_end) if date_end.present?
        when "Meldeschluss"
          date_begin, time_begin = value.match(/\s*(\d+\.\d+\.\d+)\s*(?:\((.*) Uhr\))?.*/).to_a[1..-1]
          self.accredation_end = DateTime.parse(date_begin + "#{" #{time_begin}" if time_begin.present?}")
        when "Disziplin"
          discipline = Discipline.find_by_name(value)
          if discipline.blank? && value.present?
            discipline = Discipline.create(name: value)
          end
          self.discipline_id = discipline.andand.id || Discipline.find_by_name("-").id
        else
          self.update_attribute(mappings[label], value)
        end
      end
      self.save!
      if game_details
        # Setzliste
        seedings_prev = self.seedings
        self.seedings = []
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
                    seeding = Seeding.find_by_player_id_and_tournament_id(player.id, self.id) ||
                        Seeding.create(player_id: player.id, tournament_id: self.id)
                    state_ix = 0
                  else
                    real_club = season_participations.first.club
                    logger.info "[scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} not active in Club #{club_str} [#{club.ba_id}], Region #{region.shortname}, season #{season.name}!"
                    logger.info "[scrape_tournaments] Inkonsistence - Fixed: Player #{lastname}, #{firstname} is active in Club #{real_club.shortname} [#{real_club.ba_id}], Region #{real_club.region.shortname}, season #{season.name}!"
                    sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player.id, season.id, real_club.id) ||
                        SeasonParticipation.create(player_id: player.id, season_id: season.id, club_id: real_club.id)
                    seeding = Seeding.find_by_player_id_and_tournament_id(player.id, self.id) ||
                        Seeding.create(player_id: player.id, tournament_id: self.id)
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
                    seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, self.id) ||
                        Seeding.create(player_id: player_fixed.id, tournament_id: self.id)
                    state_ix = 0
                  elsif players.count == 1
                    player_fixed = players.first
                    logger.info "[scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} is not active in Club #{club_str} [#{club.ba_id}], region #{region.shortname} and season #{season.name}"
                    SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, club.id) ||
                        SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
                    logger.info "[scrape_tournaments] Inkonsistence - fixed: Player #{lastname}, #{firstname} set active in Club #{club_str} [#{club.ba_id}], region #{region.shortname} and season #{season.name}"
                    seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, self.id) ||
                        Seeding.create(player_id: player_fixed.id, tournament_id: self.id)
                    state_ix = 0
                  elsif players.count > 1
                    logger.info "[scrape_tournaments] Inkonsistence - Fatal: Ambiguous: Player #{lastname}, #{firstname} not active everywhere but exists in Clubs [#{players.map(&:club).map { |c| "#{c.shortname} [#{c.ba_id}]" }}] "
                    logger.info "[scrape_tournaments] Inkonsistence - temporary fix: Assume Player #{lastname}, #{firstname} is active in Clubs [#{players.map(&:club).map { |c| "#{c.shortname} [#{c.ba_id}]" }.first}] "
                    player_fixed = players.first
                    SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, club.id) ||
                        SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
                    seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, self.id) ||
                        Seeding.create(player_id: player_fixed.id, tournament_id: self.id)
                    state_ix = 0
                  end
                else
                  #(ambiguous clubs)
                  if season_participations.map(&:club_id).uniq.include?(club.id)
                    season_participation = season_participations.where(club_id: club.id).first
                    player = season_participation.player
                    seeding = Seeding.find_by_player_id_and_tournament_id(player.id, self.id) ||
                        Seeding.create(player_id: player.id, tournament_id: self.id)
                    state_ix = 0
                  else
                    logger.info "[scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} is not active in Club[#{club.ba_id}] #{club_str}, region #{region.shortname} and season #{season.name}"
                    fixed_season_participation = season_participations.last
                    fixed_club = fixed_season_participation.club
                    fixed_player = fixed_season_participation.player
                    logger.info "[scrape_tournaments] Inkonsistence - fixed: Player #{lastname}, #{firstname} playing for Club[#{fixed_club.ba_id}] #{fixed_club.shortname}, region #{fixed_club.region.shortname} and season #{season.name}"
                    SeasonParticipation.find_by_player_id_and_season_id_and_club_id(fixed_player.id, season.id, fixed_club.id) ||
                        SeasonParticipation.create(player_id: fixed_player.id, season_id: season.id, club_id: fixed_club.id)
                    seeding = Seeding.find_by_player_id_and_tournament_id(fixed_player.id, self.id) ||
                        Seeding.create(player_id: fixed_player.id, tournament_id: self.id)
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
                seeding = Seeding.find_by_player_id_and_tournament_id(fixed_player.id, self.id) ||
                    Seeding.create(player_id: fixed_player.id, tournament_id: self.id)
                state_ix = 0
              end
            else
              if td.text.strip =~ /X/
                if seeding.present?
                  seeding.update_attribute(:ba_state, states[state_ix])
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

        no_show_ups = seedings_prev - self.seedings
        no_show_ups.each do |seeding|
          seeding.status = "UNA"
        end
        self.reload
        # Results
        self.games = []
        table = doc.css("#tabs-2 .matchday_table")[0]
        keys = table.css("tr th div").map(&:text).map { |s| s.split("\n").first }
        table.css("tr").each do |row|
          game = nil
          data = {}
          row.css("td").each_with_index do |f, ix|
            data[keys[ix]] = f.text.strip
            if keys[ix] == "#"
              seqno = f.text.strip.to_i
              game = Game.find_by_seqno_and_tournament_id(seqno, self.id) || Game.new(tournament_id: self.id, seqno: seqno)
            end
          end
          if game.andand.seqno.present?
            game.gname = data["Gr."]
            game.data = data
            game.save!
            Game.fix_participation(game)
          end
        end

        # Rankings
        groups = doc.css("#tabs-1 fieldset legend").map(&:text).map { |s| s.split("\n").first }
        seedings_hash = self.seedings.includes(:player).inject({}) do |memo, seeding|
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
          data = seeding.data || {}
          data["result"] = result[name]
          seeding.data_will_change!
          seeding.data = data
          seeding.save!
        end
      end
    else
      table
    end
    update_columns(last_ba_sync_date: Time.now)
  end

  def reset_tournament
    logger.info "[reset_tournament]..."
    # called from state machine only
    # use direct only for testing purposes

    tournament_monitor.andand.destroy
    seedings.update_all(position: nil, data: nil)
    games.destroy_all
    update_attributes(tournament_plan_id: nil, state: "new_tournament")
    reload
    logger.info "state:#{state}...[reset_tournament]"
  end

  def tournament_not_yet_started
    !tournament_started
  end

  def tournament_started
    games.present?
  end

  def date_str
    if date.present?
      "#{date.to_s(:db)}#{" - #{(end_date.to_date.to_s(:db))}" if end_date.present?}"
    end
  end

  private

  def before_all_events
    Tournament.logger.info "[tournament] #{aasm.current_event.inspect}"
  end
end
