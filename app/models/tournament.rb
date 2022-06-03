require 'open-uri'
require 'net/http'
#require 'dnssd'

# == Schema Information
#
# Table name: tournaments
#
#  id                             :bigint           not null, primary key
#  accredation_end                :datetime
#  admin_controlled               :boolean          default(FALSE), not null
#  age_restriction                :string
#  allow_follow_up                :boolean          default(TRUE), not null
#  ba_state                       :string
#  balls_goal                     :integer
#  color_remains_with_set         :boolean          default(TRUE), not null
#  data                           :text
#  date                           :datetime
#  end_date                       :datetime
#  fixed_display_left             :string
#  gd_has_prio                    :boolean          default(FALSE), not null
#  handicap_tournier              :boolean
#  innings_goal                   :integer
#  kickoff_switches_with_set      :boolean          default(TRUE), not null
#  last_ba_sync_date              :datetime
#  location                       :text
#  manual_assignment              :boolean          default(FALSE)
#  modus                          :string
#  organizer_type                 :string
#  plan_or_show                   :string
#  player_class                   :string
#  sets_to_play                   :integer          default(1), not null
#  sets_to_win                    :integer          default(1), not null
#  shortname                      :string
#  single_or_league               :string
#  state                          :string
#  team_size                      :integer          default(1), not null
#  time_out_warm_up_first_min     :integer          default(5)
#  time_out_warm_up_follow_up_min :integer          default(3)
#  timeout                        :integer          default(45)
#  timeouts                       :integer          default(0), not null
#  title                          :string
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  ba_id                          :integer
#  discipline_id                  :integer
#  league_id                      :integer
#  location_id                    :integer
#  organizer_id                   :integer
#  region_id                      :integer
#  season_id                      :integer
#  tournament_plan_id             :integer
#
# Indexes
#
#  index_tournaments_on_ba_id         (ba_id) UNIQUE
#  index_tournaments_on_foreign_keys  (title,season_id,region_id)
#
class Tournament < ApplicationRecord

  DEBUG_LOGGER = Logger.new("#{Rails.root}/log/debug.log")

  include AASM
  has_paper_trail
  MIN_ID = 50000000

  belongs_to :discipline, optional: true
  belongs_to :region, optional: true
  belongs_to :season
  belongs_to :tournament_plan, optional: true
  belongs_to :league, optional: true
  has_many :seedings, -> { order(position: :asc) }, dependent: :destroy
  has_many :games, dependent: :destroy
  has_many :teams, dependent: :destroy
  has_many :party_games, dependent: :destroy
  has_one :tournament_monitor
  has_one :setting
  #noinspection RailsParamDefResolve
  belongs_to :organizer, polymorphic: true
  belongs_to :tournament_location, class_name: "Location", foreign_key: :location_id, optional: true
  has_one :tournament_local, :dependent => :nullify
  has_many :party_tournaments
  has_many :parties, :through => :party_tournaments

  scope :active_manual_assignment, -> { where(state: "tournament_started").where(manual_assignment: true) }

=begin
  data:
    {:table_ids=>["2", "4"],
     :balls_goal=>0,
     :innings_goal=>15,
     :timeout=>0,
     :timeouts=>0,
     :time_out_warm_up_first_min=>5,
     :time_out_warm_up_follow_up_min=>3},
=end
  serialize :data, Hash

  validates_each :data do |record, attr, _value|
    table_ids = Array(record.send(attr)[:table_ids])
    if table_ids.present?
      incomplete = table_ids.length != record.tournament_plan.andand.tables.to_i && !record.manual_assignment
      heterogen = Table.where(id: table_ids).all.map(&:location_id).uniq.length > 1
      inconsistent = table_ids != table_ids.uniq
      record.errors.add(attr, I18n.t('table_assignments_incomplete')) if incomplete
      record.errors.add(attr, I18n.t('table_assignments_heterogen')) if heterogen
      record.errors.add(attr, I18n.t('table_assignments_inconsistent')) if inconsistent
    end
  end

  [:timeouts, :timeout, :gd_has_prio, :admin_controlled, :sets_to_play, :sets_to_win,
   :team_size, :kickoff_switches_with_set, :allow_follow_up,
   :fixed_display_left, :color_remains_with_set].each do |meth|
    define_method(meth) do
      (id < Tournament::MIN_ID && tournament_local.present?) ? tournament_local.send(meth) : read_attribute(meth)
    end

    define_method("#{meth}=") do |value|
      if new_record?
        write_attribute(meth, value)
      else
        if id < Tournament::MIN_ID
          tol = tournament_local.presence || create_tournament_local(
            timeouts: read_attribute(timeouts).to_i,
            timeout: read_attribute(timeout).to_i,
            gd_has_prio: (read_attribute(gd_has_prio).present? ? false : true),
            admin_controlled: (read_attribute(admin_controlled).present? ? false : true),
            sets_to_play: (read_attribute(sets_to_play) || 1),
            sets_to_win: (read_attribute(sets_to_win).presence || 1),
            team_size: (read_attribute(team_size).presence || 1),
            kickoff_switches_with_set: (read_attribute(kickoff_switches_with_set).present? ? false : true),
            allow_follow_up: (read_attribute(allow_follow_up).present? ? false : true),
            fixed_display_left: (read_attribute(fixed_display_left).present? ? false : true),
            color_remains_with_set: (read_attribute(color_remains_with_set).present? ? false : true)
          )
          tol.update(meth => value)
        else
          write_attribute(meth, value)
        end
      end
    end
  end

  aasm column: 'state', skip_validation_on_save: true do
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

  before_save do
    if date.blank?
      self.date = Time.at(0)
    end
    if organizer.blank?
      self.organizer = self.region
    end
  end

  def self.logger
    DEBUG_LOGGER
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

  COLUMN_NAMES = { #TODO FILTERS
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
    Tournament.logger.info "[initialize_tournament_monitor]..."
    TournamentMonitor.transaction do
      # http = TCPServer.new nil, 80
      # DNSSD.announce http, 'carambus server'
      # Setting.key_set_val(:carambus_server_status, "ready to accept connections from scoreboards")
      games.where("games.id >= #{Game::MIN_ID}").destroy_all
      create_tournament_monitor unless tournament_monitor.present?
      Tournament.logger.info "state:#{state}...[initialize_tournament_monitor]"
    rescue StandardError => e
      Tournament.logger.info "...[initialize_tournament_monitor] StandardError #{e}:\n#{e.backtrace.to_a.join("\n")}"
      Rails.logger.error("Some problem occurred when creating TournamentMonitor - Tournament resetted")
      reset_tournament
    end

  end

  def t_no_from(table)
    self.data[:table_ids].to_a.each_with_index do |table_id, ix|
      return ix + 1 if table_id.to_i == table.id
    end
    1
  end

  def player_controlled?
    # players can advance from Game-Finished-OK without admin or referee interaction?
    !admin_controlled?
  end

  def scrape_single_tournament(opts = {})
    self.reset_tournament
    logger = opts[:logger] || Logger.new("#{Rails.root}/log/scrape.log")
    game_details = opts.keys.include?(:game_details) ? opts[:game_details] : true
    season = self.season
    region = self.region
    region ||= self.organizer
    url = "https://#{region.shortname.downcase}.billardarea.de"
    if self.single_or_league == "single"
      url_tournament = "/cms_#{self.single_or_league}/show/#{self.ba_id}"
      Rails.logger.info "reading #{url + url_tournament} - \"#{self.title}\" season #{season.name}"
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
          date_begin, time_begin, date_end = value.match(/\s*(\d+\.\d+\.\d+)\s*(?:\((.*) Uhr\))?(?:\s+-\s+(\d+\.\d+\.\d+))?.*/).to_a[1..-1]
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
      self.data = {}
      self.save!
      if game_details
        # Setzliste
        #seedings_prev = self.seedings
        self.seedings = []
        table = doc.css("#tabs-3 .matchday_table")[0]
        if table.present?
          states = %w{FG NG ENA UNA DIS}
          state_ix = 0
          seeding = nil
          table.css("td").each do |td|
            if td.css("div").present?
              lastname, firstname, club_str = td.css("div").text.strip.match(/(.*),\s*(.*)\s*\((.*)\)/).to_a[1..-1].map(&:strip)
              player, seeding, state_ix = Player.fix_from_shortnames(lastname, firstname, season, region, club_str, self, true, true)
              club = Club.where(region: region).where("name ilike ?", club_str).first ||
                Club.where(region: region).where("shortname ilike ?", club_str).first
              if club.present?
                season_participations = SeasonParticipation.joins(:player).joins(:club).joins(:season).where(seasons: { id: season.id }, players: { firstname: firstname, lastname: lastname })
                if season_participations.count == 1
                  season_participation = season_participations.first
                  player = season_participation.player
                  if season_participation.club_id == club.id
                    seeding = Seeding.find_by_player_id_and_tournament_id(player.id, self.id) ||
                      Seeding.create(player_id: player.id, tournament_id: self.id)
                    seeding_ids.delete(seeding.id)
                    state_ix = 0
                  else
                    real_club = season_participations.first.club
                    logger.info "[scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} not active in Club #{club_str} [#{club.ba_id}], Region #{region.shortname}, season #{season.name}!"
                    logger.info "[scrape_tournaments] Inkonsistence - Fixed: Player #{lastname}, #{firstname} is active in Club #{real_club.shortname} [#{real_club.ba_id}], Region #{real_club.region.shortname}, season #{season.name}!"
                    sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player.id, season.id, real_club.id) ||
                      SeasonParticipation.create(player_id: player.id, season_id: season.id, club_id: real_club.id)
                    seeding = Seeding.find_by_player_id_and_tournament_id(player.id, self.id) ||
                      Seeding.create(player_id: player.id, tournament_id: self.id)
                    seeding_ids.delete(seeding.id)
                    state_ix = 0
                  end
                elsif season_participations.count == 0
                  players = Player.where(type: nil).where(firstname: firstname, lastname: lastname)
                  if players.count == 0
                    logger.info "[scrape_tournaments] Inkonsistence - Fatal: Player #{lastname}, #{firstname} not found in club #{club_str} [#{club.ba_id}] , Region #{region.shortname}, season #{season.name}! Not found anywhere - typo?"
                    logger.info "[scrape_tournaments] Inkonsistence - fixed - added Player Player #{lastname}, #{firstname} active to club #{club_str} [#{club.ba_id}] , Region #{region.shortname}, season #{season.name}"
                    player_fixed = Player.create(lastname: lastname, firstname: firstname, club_id: club.id)
                    player_fixed.update(ba_id: 999000000 + player_fixed.id)
                    SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, club.id) ||
                      SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
                    seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, self.id) ||
                      Seeding.create(player_id: player_fixed.id, tournament_id: self.id)
                    seeding_ids.delete(seeding.id)
                    state_ix = 0
                  elsif players.count == 1
                    player_fixed = players.first
                    logger.info "[scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} is not active in Club #{club_str} [#{club.ba_id}], region #{region.shortname} and season #{season.name}"
                    SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, club.id) ||
                      SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
                    logger.info "[scrape_tournaments] Inkonsistence - fixed: Player #{lastname}, #{firstname} set active in Club #{club_str} [#{club.ba_id}], region #{region.shortname} and season #{season.name}"
                    seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, self.id) ||
                      Seeding.create(player_id: player_fixed.id, tournament_id: self.id)
                    seeding_ids.delete(seeding.id)
                    state_ix = 0
                  elsif players.count > 1
                    logger.info "[scrape_tournaments] Inkonsistence - Fatal: Ambiguous: Player #{lastname}, #{firstname} not active everywhere but exists in Clubs [#{players.map(&:club).map { |c| "#{c.shortname} [#{c.ba_id}]" }}] "
                    logger.info "[scrape_tournaments] Inkonsistence - temporary fix: Assume Player #{lastname}, #{firstname} is active in Clubs [#{players.map(&:club).map { |c| "#{c.shortname} [#{c.ba_id}]" }.first}] "
                    player_fixed = players.first
                    SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, club.id) ||
                      SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
                    seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, self.id) ||
                      Seeding.create(player_id: player_fixed.id, tournament_id: self.id)
                    seeding_ids.delete(seeding.id)
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
                    seeding_ids.delete(seeding.id)
                    state_ix = 0
                  end
                end
              else
                logger.info "[scrape_tournaments] Inkonsistence - fatal: Club #{club_str}, region #{region.shortname} not found!! Typo?"
                fixed_club = region.clubs.create(name: club_str, shortname: club_str)
                fixed_player = fixed_club.players.create(firstname: firstname, lastname: lastname)
                fixed_club.update(ba_id: 999000000 + fixed_club.id)
                fixed_player.update(ba_id: 999000000 + fixed_player.id)
                SeasonParticipation.create(player_id: fixed_player.id, season_id: season.id, club_id: fixed_club.id)

                logger.info "[scrape_tournaments] Inkonsistence - temporary fix: Club #{club_str} created in region #{region.shortname}"
                logger.info "[scrape_tournaments] Inkonsistence - temporary fix: Player #{lastname}, #{firstname} playing for Club #{club_str}"
                seeding = Seeding.find_by_player_id_and_tournament_id(fixed_player.id, self.id) ||
                  Seeding.create(player_id: fixed_player.id, tournament_id: self.id)
                seeding_ids.delete(seeding.id)
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
        #
        # no_show_ups = seedings_prev - self.seedings
        # no_show_ups.each do |seeding|
        #   seeding.status = "UNA"
        # end
        self.reload
        # Results
        self.games.where("games.id >= #{Game::MIN_ID}").destroy_all
        self.reload
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

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    self.data_will_change!
    self.data = JSON.parse(h.to_json)
    save!
  end

  def reset_tournament
    Tournament.logger.info "[reset_tournament]..."
    # called from state machine only
    # use direct only for testing purposes
    tournament_monitor.andand.destroy
    unless organizer.is_a? Club
      seedings.where("seedings.id >= #{Seeding::MIN_ID}").destroy_all
    end
    games.where("games.id >= #{Game::MIN_ID}").destroy_all
    unless new_record?
      update(tournament_plan_id: nil, state: "new_tournament", data: {})
      reload
      reorder_seedings
    end
    Tournament.logger.info "state:#{state}...[reset_tournament]"
  end

  def reorder_seedings
    l_seeding_ids = seeding_ids
    l_seeding_ids.each_with_index do |seeding_id, ix|
      Seeding.find_by_id(seeding_id).update_columns(position: ix + 1)
    end
    reload
  end

  def tournament_not_yet_started
    !tournament_started
  end

  def tournament_started
    games.where("games.id >= #{Game::MIN_ID}").present?
  end

  def date_str
    if date.present?
      "#{date.to_s(:db)}#{" - #{(end_date.to_date.to_s(:db))}" if end_date.present?}"
    end
  end

  def name
    title || shortname
  end

  private

  def before_all_events
    Tournament.logger.info "[tournament] #{aasm.current_event.inspect}"
  end
end
