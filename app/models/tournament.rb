# frozen_string_literal: true

require "net/http"
# require 'dnssd'

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
#  continuous_placements          :boolean          default(FALSE), not null
#  data                           :text
#  date                           :datetime
#  end_date                       :datetime
#  fixed_display_left             :string
#  gd_has_prio                    :boolean          default(FALSE), not null
#  handicap_tournier              :boolean
#  innings_goal                   :integer
#  kickoff_switches_with          :string
#  location_text                  :text
#  manual_assignment              :boolean          default(FALSE)
#  modus                          :string
#  organizer_type                 :string
#  plan_or_show                   :string
#  player_class                   :string
#  sets_to_play                   :integer          default(1), not null
#  sets_to_win                    :integer          default(1), not null
#  shortname                      :string
#  single_or_league               :string
#  source_url                     :string
#  state                          :string
#  sync_date                      :datetime
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
#  index_tournaments_on_ba_id  (ba_id) UNIQUE
#
class Tournament < ApplicationRecord
  include LocalProtector
  include SourceHandler
  include RegionTaggable
  include Searchable
  DEBUG_LOGGER = Logger.new("#{Rails.root}/log/debug.log")

  include AASM

  before_save :set_paper_trail_whodunnit
  MIN_ID = 50_000_000

  belongs_to :discipline, optional: true
  belongs_to :region, optional: true
  belongs_to :season
  belongs_to :tournament_plan, optional: true
  belongs_to :league, optional: true
  has_many :seedings, -> { order(position: :asc) }, as: :tournament, dependent: :destroy
  # has_many :games, as: :tournament, class_name: "Game", dependent: :destroy
  has_many :games, as: :tournament, dependent: :destroy
  has_many :teams, dependent: :destroy
  has_one :tournament_monitor, dependent: :destroy
  has_one :tournament_cc, class_name: "TournamentCc", foreign_key: :tournament_id, dependent: :destroy
  has_one :setting, dependent: :destroy
  # noinspection RailsParamDefResolve
  belongs_to :organizer, polymorphic: true
  belongs_to :location, optional: true
  has_one :tournament_local, dependent: :destroy

  scope :active_manual_assignment, -> { where(state: "tournament_started").where(manual_assignment: true) }

  #   data:
  #     {:table_ids=>["2", "4"],
  #      :balls_goal=>0,
  #      :innings_goal=>15,
  #      :timeout=>0,
  #      :timeouts=>0,
  #      :time_out_warm_up_first_min=>5,
  #      :time_out_warm_up_follow_up_min=>3},
  #
  serialize :data, coder: JSON, type: Hash

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
    "Freie Partie" => "Freie Partie klein"
  }.freeze

  REFLECTIONS = %w[versions
                   discipline
                   region
                   season
                   tournament_plan
                   league
                   seedings
                   games
                   teams
                   party_games
                   tournament_monitor
                   tournament_cc
                   setting
                   organizer
                   location
                   tournament_local
                   parties].freeze

  COLUMN_NAMES = {
    # IDs (versteckt, nur für Backend-Filterung)
    "id" => "tournaments.id",
    "region_id" => "regions.id",
    "season_id" => "seasons.id",
    "discipline_id" => "disciplines.id",
    "location_id" => "locations.id",

    # Externe IDs (sichtbar, filterbar)
    "CC_ID" => "tournament_ccs.cc_id",

    # Referenzen (Dropdown/Select)
    "Region" => "regions.shortname",
    "Season" => "seasons.name",
    "Discipline" => "disciplines.name",
    "Location" => "locations.name",

    # Eigene Felder
    "Title" => "tournaments.title",
    "Shortname" => "tournaments.shortname",
    "Date" => "tournaments.date::date",
  }.freeze

  self.ignored_columns = ["region_ids"]

  # Searchable concern provides search_hash, we only need to define the specifics

  def self.text_search_sql
    "(tournaments.ba_id = :isearch)
     or (tournaments.title ilike :search)
     or (tournaments.shortname ilike :search)
     or (seasons.name ilike :search)"
  end

  def self.search_joins
    # Organizer ist polymorphisch (Region), daher custom JOIN
    # LEFT JOIN für optionale Assoziationen (discipline, tournament_cc, location)
    # damit Turniere ohne diese Daten trotzdem gefunden werden
    [
      'INNER JOIN "regions" ON ("regions"."id" = "tournaments"."organizer_id" AND "tournaments"."organizer_type" = \'Region\')',
      'INNER JOIN "seasons" ON "seasons"."id" = "tournaments"."season_id"',
      'LEFT JOIN "disciplines" ON "disciplines"."id" = "tournaments"."discipline_id"',
      'LEFT JOIN "tournament_ccs" ON "tournament_ccs"."tournament_id" = "tournaments"."id"',
      'LEFT JOIN "locations" ON "locations"."id" = "tournaments"."location_id"'
    ]
  end

  def self.search_distinct?
    false
  end

  def self.cascading_filters
    {
      'season_id' => [] # Season ist unabhängig, könnte aber Disciplines filtern (optional)
    }
  end

  def self.field_examples(field_name)
    case field_name
    when 'Title'
      { description: "Turniertitel", examples: ["Stadtmeisterschaft", "Pokalturnier"] }
    when 'Shortname'
      { description: "Kurzbezeichnung des Turniers", examples: ["SM2024", "Cup"] }
    when 'Date'
      { description: "Turnierdatum", examples: ["2024-01-15", "> 2024-01-01", "heute"] }
    when 'CC_ID'
      { description: "Externe Turnier-ID", examples: ["12345"] }
    when 'Region'
      { description: "Region/Veranstalter auswählen", examples: [] }
    when 'Season'
      { description: "Saison auswählen", examples: [] }
    when 'Discipline'
      { description: "Disziplin auswählen", examples: [] }
    when 'Location'
      { description: "Spielort auswählen", examples: [] }
    else
      super
    end
  end

  validates_each :data do |record, attr, _value|
    table_ids = Array(record.send(attr)[:table_ids])
    if table_ids.present?
      incomplete = table_ids.length != record.tournament_plan.andand.tables.to_i &&
        !record.manual_assignment && record.tournament_plan.andand.tables.to_i < 999
      heterogen = Table.where(id: table_ids).all.map(&:location_id).uniq.length > 1
      inconsistent = table_ids != table_ids.uniq
      record.errors.add(attr, I18n.t("table_assignments_incomplete")) if incomplete
      record.errors.add(attr, I18n.t("table_assignments_heterogen")) if heterogen
      record.errors.add(attr, I18n.t("table_assignments_inconsistent")) if inconsistent
    end
  end

  %i[timeouts timeout gd_has_prio admin_controlled auto_upload_to_cc sets_to_play sets_to_win
     team_size kickoff_switches_with allow_follow_up allow_overflow
     fixed_display_left color_remains_with_set].each do |meth|
    define_method(meth) do
      id.present? && id < Tournament::MIN_ID && tournament_local.present? ? tournament_local.send(meth) : read_attribute(meth)
    end

  define_method(:"#{meth}=") do |value|
    if new_record?
      write_attribute(meth, value)
    elsif id < Tournament::MIN_ID
      tol = tournament_local.presence || create_tournament_local(
        timeouts: read_attribute(:timeouts).to_i,
        timeout: read_attribute(:timeout).to_i,
        gd_has_prio: read_attribute(:gd_has_prio),
        admin_controlled: read_attribute(:admin_controlled),
        sets_to_play: read_attribute(:sets_to_play) || 1,
        sets_to_win: read_attribute(:sets_to_win).presence || 1,
        team_size: read_attribute(:team_size).presence || 1,
        kickoff_switches_with: read_attribute(:kickoff_switches_with),
        allow_follow_up: read_attribute(:allow_follow_up),
        allow_overflow: read_attribute(:allow_overflow),
        fixed_display_left: read_attribute(:fixed_display_left),
        color_remains_with_set: read_attribute(:color_remains_with_set)
      )
      tol.update(meth => value)
    else
      write_attribute(meth, value)
    end
  end
  end

  aasm column: "state", skip_validation_on_save: true do
    state :new_tournament, initial: true, after_enter: [:reset_tournament]
    state :accreditation_finished
    state :tournament_seeding_finished, after_enter: [:calculate_and_cache_rankings]
    state :tournament_mode_defined
    state :tournament_started_waiting_for_monitors
    state :tournament_started
    state :tournament_finished
    state :results_published
    state :closed
    before_all_events :before_all_events
    event :finish_seeding do
      transitions from: %i[new_tournament accreditation_finished tournament_seeding_finished],
                  to: :tournament_seeding_finished
    end
    event :finish_mode_selection do
      transitions from: %i[new_tournament tournament_seeding_finished tournament_mode_defined],
                  to: :tournament_mode_defined
    end
    event :start_tournament! do
      transitions from: %i[tournament_started tournament_mode_defined tournament_started_waiting_for_monitors],
                  to: :tournament_started_waiting_for_monitors
    end
    event :signal_tournament_monitors_ready do
      transitions from: %i[tournament_started tournament_mode_defined tournament_started_waiting_for_monitors],
                  to: :tournament_started
    end
    event :reset_tmt_monitor do
      transitions to: :new_tournament, guard: %i[tournament_not_yet_started admin_can_reset_tournament?]
    end
    event :forced_reset_tournament_monitor do
      transitions to: :new_tournament, guard: :admin_can_reset_tournament?
    end
    event :finish_tournament do
      transitions to: :tournament_finished
    end

    event :have_results_published do
      transitions from: :tournament_finished, to: :results_published
    end
  end

  before_save do
    self.date = Time.at(0) if date.blank?
    self.organizer = region if organizer.blank?

    # Only process data if it's not nil and has content
    if data.present?
      %w[balls_goal innings_goal time_out_warm_up_first_min
         time_out_warm_up_follow_up_min kickoff_switches_with fixed_display_left] +
        %w[timeouts timeout gd_has_prio admin_controlled auto_upload_to_cc sets_to_play sets_to_win
           team_size kickoff_switches_with allow_follow_up allow_overflow
           fixed_display_left color_remains_with_set].each do |meth|
          # Use !nil? instead of present? to allow 0 and false as valid values
          if !data[meth].nil?
            data_will_change!
            write_attribute(meth, data.delete(meth))
          end
        end
    end
  end

  def cc_id
    tournament_cc.andand.cc_id
  end

  def self.logger
    DEBUG_LOGGER
  end

  def initialize_tournament_monitor
    Tournament.logger.info "[initialize_tournament_monitor]..."
    TournamentMonitor.transaction do
      # http = TCPServer.new nil, 80
      # DNSSD.announce http, 'carambus server'
      # Setting.key_set_val(:carambus_server_status, "ready to accept connections from scoreboards")
      games.where("games.id >= #{Game::MIN_ID}").destroy_all
      unless tournament_monitor.present?
        # Erstelle TournamentMonitor mit initialisierten Parametern vom Tournament
        # DB-Defaults sind korrekt gesetzt, daher keine nil-Checks nötig
        create_tournament_monitor(
          timeout: timeout || 0,
          timeouts: timeouts || 0,
          innings_goal: innings_goal,
          balls_goal: balls_goal,
          sets_to_play: sets_to_play || 1,
          sets_to_win: sets_to_win || 1,
          team_size: team_size || 1,
          kickoff_switches_with: kickoff_switches_with,
          allow_follow_up: allow_follow_up,
          color_remains_with_set: color_remains_with_set,
          allow_overflow: allow_overflow,
          fixed_display_left: fixed_display_left
        )
      end
      Tournament.logger.info "state:#{state}...[initialize_tournament_monitor]"
    rescue StandardError => e
      Tournament.logger.info "...[initialize_tournament_monitor] StandardError #{e}:\n#{e.backtrace.to_a.join("\n")}"
      Rails.logger.error("Some problem occurred when creating TournamentMonitor - Tournament resetted")
      reset_tournament
    end
  end

  def t_no_from(table)
    data["table_ids"].to_a.each_with_index do |table_id, ix|
      return ix + 1 if table_id.to_i == table.id
    end
    1
  end

  def player_controlled?
    # players can advance from Game-Finished-OK without admin or referee interaction?
    !admin_controlled?
  end

  def match_location_from_location_text
    lt = location_text
    name, _address, _zipcode, _city, _tel = lt.split('\n')
    Location.find_by_synonyms(name)
  end

  def scrape_single_tournament_public(opts = {})
    nbsp = ["c2a0"].pack("H*").force_encoding("UTF-8")
    return if organizer_type != "Region"
    return if Carambus.config.carambus_api_url.present?
    region = organizer if organizer_type == "Region"
    url = organizer.public_cc_url_base
    region_cc = region.region_cc
    tournament_doc = opts[:tournament_doc]
    region_cc_cc_id = region_cc.cc_id
    tc = tournament_cc
    tournament_cc_id = tc.andand.cc_id
    tournament_link = "sb_meisterschaft.php?p=#{region_cc_cc_id}--#{season.name}-#{tournament_cc_id}-0--2-1-100000-"
    unless tournament_doc.present?
      if tournament_cc_id.blank?
        tournament_link_ = "sb_meisterschaft.php?p=#{region_cc_cc_id}--#{season.name}--0--2-1-100000-"
        Rails.logger.info "reading #{url + tournament_link_}"
        uri = URI(url + tournament_link_)
        tournament_html = Rails.env == 'development' ?  Version.http_get_with_ssl_bypass(uri) : Net::HTTP.get(uri)
        tournament_doc_ = Nokogiri::HTML(tournament_html_)
        tournament_cc_id = nil
        tournament_doc_.css("article table.silver").andand[1].andand.css("tr").to_a[2..].to_a.each do |tr|
          next unless tr.css("a")[0].text.gsub(nbsp, " ").strip == title

          tournament_link_ = tr.css("a")[0].attributes["href"].value
          params = tournament_link_.split("p=")[1].split("-")
          tournament_cc_id = params[3].to_i
          break
        end
        tc = TournamentCc.find_by_cc_id_and_context(tournament_cc_id, region_cc.context)
        tc ||= create_tournament_cc!
        tc.assign_attributes(name: title, season: season.name, context: region_cc.context, cc_id: tournament_cc_id,
                             tournament_id: id)

        tc.save! if tc.changed?
        reload
      else
        unless tournament_cc.andand.name == title
          raise StandardError,
                "Fatal mismatch Tournament#title: #{title} and TournamenCc#name: #{tournament_cc.andand.name}"
        end
      end
      tournament_link = "sb_meisterschaft.php?p=#{region_cc_cc_id}--#{season.name}-#{tournament_cc_id}----1-100000-"
      Rails.logger.info "reading #{url + tournament_link}"
      uri = URI(url + tournament_link)
      tournament_html = Rails.env == 'development' ?  Version.http_get_with_ssl_bypass(uri) : Net::HTTP.get(uri)
      Rails.logger.info "===== scrape =========================== SCRAPING TOURNAMENT '#{url + tournament_link}'"
      tournament_doc = Nokogiri::HTML(tournament_html)
    end
    self.source_url = url + tournament_link
    # details
    detail_table = tournament_doc.css("aside table.silver")[0]
    branch_cc = nil
    discipline = nil
    detail_table.css("tr").each do |detail_tr|
      next unless detail_tr.css("td")[0].present?

      case detail_tr.css("td")[0].text.gsub(nbsp, " ").strip
      when "Kürzel"
        self.shortname = tc.shortname = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
      when "Datum"
        ht = detail_tr.css("td")[1].inner_html
        date_time = DateTime.parse(ht.match(/.*Spielbeginn am (.*) Uhr.*/)[1].andand.gsub("um ", ""))
        tc.tournament_start = date_time
        self.date = date_time
      when "Location"
        ht = detail_tr.css("td")[1].inner_html
        location = nil
        location_name, location_address = ht.match(%r{<strong>(.*)</strong><br>(.*)})[1..2]
        street = location_address.split("<br>").first&.split(",")&.first&.strip
        location = Location.where("address ilike ?", "#{street}%").first if street.present?
        if !location.present? && location_name.present?
          location = Location.new(name: location_name, address: location_address, organizer: self)
          location.region_id = region.id
          md5 = location.md5_from_attributes
          loc_by_md5 = Location.where(md5: md5).first
          location = loc_by_md5 if loc_by_md5.present?
        end
        self.location = tc.location = location
      when "Meldeschluss"
        text = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
        date_time = DateTime.parse(text)
        self.accredation_end = date_time
      when "Sparte"
        name = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
        branch_cc = BranchCc.where(name:, context: region_cc.context).first
        if branch_cc.present?
          tc.branch_cc_id = branch_cc.id
        else
          Rails.logger.info "===== scrape ===== Problem Branch name #{name} db-unknown - should not happen here!"
        end
      when "Kategorie"
        name = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
        category_cc = CategoryCc.where(name:, context: region_cc.context).first
        if category_cc.present?
          tc.category_cc_id = category_cc.id
        else
          tc.category_cc_name = name
        end
      when "Meisterschaftstyp"
        name = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
        championship_type_cc = ChampionshipTypeCc.where(name:, context: region_cc.context).first
        if championship_type_cc.present?
          tc.championship_type_cc_id = championship_type_cc.id
        else
          tc.championship_type_cc_name = name
        end
      when "Disziplin"
        discipline_name = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
        discipline = Discipline.where("synonyms ilike ?", "%#{discipline_name}%").to_a.find do |dis|
          dis.synonyms.split("\n").include?(discipline_name)
        end
        unless discipline.present?
          discipline = Discipline.create(name: discipline_name, super_discipline_id: branch_cc.andand.id)
        end
        tc.discipline_id = self.discipline_id = discipline.id
      else
        next
      end
    end
    tc.save
    self.region_id = region.id
    save!
    # Meldeliste
    # Nur beim Archivieren (reload_game_results: true) alte Seedings aufräumen
    # Beim Setup (reload_game_results: false) bestehende Seedings NICHT löschen!
    if opts[:reload_game_results] || opts[:reload_seedings]
      reload.seedings.destroy_all
    end
    player_list = {}
    registration_link = tournament_link.gsub("meisterschaft", "meldeliste")
    Rails.logger.info "reading #{url + registration_link}"
    uri = URI(url + registration_link)
    registration_html = Rails.env == 'development' ?  Version.http_get_with_ssl_bypass(uri) : Net::HTTP.get(uri)
    registration_doc = Nokogiri::HTML(registration_html)
    registration_table = registration_doc.css("aside table.silver table")[0]
    _header = []
    if registration_table.present?
      registration_table.css("tr")[1..].each_with_index do |tr, ix|
        if tr.css("th").count > 1
          _header = tr.css("th").map(&:text)
        elsif tr.css("td").count.positive?
          _n = tr.css("td")[0].text.to_i
          # New format: td[2] contains player name in <b> tag and club after <br>
          player_td = tr.css("td")[2]
          if player_td.present?
            # Extract player name (in bold) and club (after <br>)
            lines = player_td.inner_html.gsub(/<b>|<\/b>/, '').split(/<br>/i).map { |line| line.gsub(nbsp, " ").strip }
            player_fullname = lines[0] if lines[0].present?
            club_name = lines[1] if lines[1].present?
            
            # Split player name on last space (lastname is after last space)
            if player_fullname.present?
              last_space_index = player_fullname.rindex(' ')
              if last_space_index
                player_fname = player_fullname[0...last_space_index].strip
                player_lname = player_fullname[last_space_index+1..-1].strip
              else
                player_fname = ''
                player_lname = player_fullname.strip
              end
              
              club_name = club_name.andand.gsub("1.", "1. ").andand.gsub("1.  ", "1. ") if club_name.present?
              # Don't create seedings yet - just collect players from registration list
              player, club, _seeding, _state_ix = Player.fix_from_shortnames(player_lname, player_fname,
                                                                             season, region,
                                                                             club_name, nil,
                                                                             true, true, ix)
              player_list[player.fl_name] = [player, club, ix] if player.present?
            end
          end
        end
      end
    end
    # Seedings ohne Player-Zuordnung immer aufräumen
    reload.seedings.where(player: nil).destroy_all
    # Teilnehmerliste
    # player_list = {}
    tournament_doc.css("aside .stanne table.silver table").each do |table|
      next unless table.css("tr th")[0].andand.text.gsub(nbsp, " ").strip == "TEILNEHMERLISTE"

      table.css("tr")[2..].each_with_index do |tr, ix|
        _n = tr.css("td")[0].text.to_i
        name_match = tr.css("td")[2].inner_html.match(%r{<strong>(.*)[,\/](.*)</strong><br>(.*)})
        if name_match
          player_lname, player_fname, club_name = name_match[1..3]
        else
          name_match = tr.css("td")[2].inner_html.match(%r{<strong>(.*)\s+(\w+)</strong><br>(.*)})
          if name_match
            player_fname, player_lname, club_name = name_match[1..3]
          else
            name_match = tr.css("td")[2].inner_html.match(%r{<strong>(.*)</strong><br>(.*)})
            player_lname, club_name = name_match[1..2]
          end
        end
        club_name = club_name.andand.gsub("1.", "1. ").andand.gsub("1.  ", "1. ")
        # Don't create seedings yet - just collect players from participant list
        player, club, _seeding, _state_ix = Player.fix_from_shortnames(player_lname, player_fname, season, region,
                                                                       club_name.strip, nil,
                                                                       true, true, ix)
        # Only add to player_list if not already present (registration list takes precedence for position)
        player_list[player.fl_name] ||= [player, club, ix] if player.present?
      end
    end
    
    # Now create seedings for all players in the unified player_list
    Rails.logger.info "==== scrape ==== Creating seedings for #{player_list.count} players from combined registration and participant lists"
    player_list.each_with_index do |(fl_name, (player, club, position)), idx|
      next unless player.present?
      
      seeding = Seeding.find_by_player_id_and_tournament_id(player.id, id)
      unless seeding.present?
        seeding = Seeding.new(player_id: player.id, tournament: self, position: position || idx)
        seeding.region_id = region.id
        if seeding.save
          Rails.logger.info("Seeding[#{seeding.id}] created for #{fl_name}.")
        else
          Rails.logger.error("==== scrape ==== Failed to create seeding for player #{player.id} (#{fl_name}): #{seeding.errors.full_messages.join(', ')}")
        end
      end
    end
    
    reload
    return if discipline&.name == "Biathlon"

    # Delete games BEFORE processing results (if reload_game_results is true)
    # This ensures orphan games are deleted even if the results table doesn't exist
    # IMPORTANT: Use destroy_all (not delete_all) to create PaperTrail versions for synchronization with local servers
    if opts[:reload_game_results]
      games_to_delete = Game.where(tournament_id: self.id)
      count_before = games_to_delete.count
      if count_before > 0
        Rails.logger.info "Deleting #{count_before} game(s) for tournament #{self.id} (reload_game_results: true)"
        games_to_delete.destroy_all
        count_after = Game.where(tournament_id: self.id).count
        Rails.logger.info "After deletion: #{count_after} game(s) remaining for tournament #{self.id}"
      end
    end

    # Ergebnisse
    result_link = tournament_link.gsub("meisterschaft", "einzelergebnisse")
    result_url = url + result_link
    Rails.logger.info "reading #{result_url}"
    uri = URI(result_url)
    result_html = Rails.env == 'development' ?  Version.http_get_with_ssl_bypass(uri) : Net::HTTP.get(uri)
    result_doc = Nokogiri::HTML(result_html)
    table = result_doc.css("aside table.silver")[1]
    if table.present?
      group_options = result_doc.css('select[name="groupItemId"] > option').each_with_object({}) do |o, memo|
        memo[o["value"]] = o.text unless o["value"] == "*"
      end
      group_option_values = group_options.values
      group_cc = tc.group_cc
      unless group_cc.present?
        GroupCc.where(branch_cc: tc.branch_cc).each do |gcc|
          if JSON.parse(gcc.data)["positions"].andand.values == group_option_values
            group_cc = gcc
            break
          end
        end
      end
      unless group_cc.present?
        group_cc = GroupCc.create!(
          context: region_cc.context,
          name: "Unknown Group - scraped from TournamentCc[#{tc.id}]",
          display: "Gruppen",
          status: "Freigegeben",
          branch_cc_id: tc.branch_cc_id,
          data: { "positions" => group_options }.to_json
        )
        tc.assign_attributes(group_cc: group_cc)
      end
      player_options = result_doc.css('select[name="teilnehmerId"] > option').each_with_object({}) do |o, memo|
        memo[o["value"]] = o.text unless o["value"] == "*"
      end
      player_options.each do |k, v|
        lastname, firstname = v.split(/[,\/]/).map(&:strip)
        firstname&.gsub!(/\s*\((.*)\)/, "")
        fl_name = "#{firstname} #{lastname}".strip
        player = player_list[fl_name].andand[0]
        if player.present?
          player.assign_attributes(cc_id: k.to_i) unless organizer.shortname == "DBU"
          if player.new_record?
            player.source_url ||= result_url unless organizer.shortname == "DBU"
          end
          player.region_id ||= region.id
          player.save if player.changed?
        else
          Rails.logger.info("===== scrape ===== Inconsistent Playerlist Player #{[k, v].inspect}")
        end
      end
      # games.destroy_all if opts[:reload_game_results]
      group = nil
      frame1_lines = result_lines = td_lines = 0
      result = nil
      no = nil
      playera_fl_name = nil
      playerb_fl_name = nil
      frames = []
      frame_points = []
      innings = []
      hs = []
      hb = []
      mp = []
      header = []
      gd = []
      points = []
      frame_result = []
      table.css("tr").each do |tr|
        frame1_lines, frame_points, frame_result, frames, gd, group, hb, header, hs, mp, innings, nbsp, no,
          player_list, playera_fl_name, playerb_fl_name, points, result, result_lines, result_url,
          td_lines, _tr = parse_table_tr(region,
                                         frame1_lines, frame_points, frame_result, frames, gd, group, hb,
                                         header, hs, mp, innings, nbsp, no, player_list, playera_fl_name, playerb_fl_name,
                                         points, result, result_lines, result_url, td_lines, tr
        )
      end
      if td_lines.positive? && no.present?
        handle_game(region, frame_result, frames, gd, group, hs, hb, mp, innings, no, player_list, playera_fl_name,
                    playerb_fl_name, frame_points, points, result)
      end
    end

    # Rangliste
    ranking_link = tournament_link.gsub("meisterschaft", "einzelrangliste")
    Rails.logger.info "reading #{url + ranking_link}"
    uri = URI(url + ranking_link)
    ranking_html = Rails.env == 'development' ?  Version.http_get_with_ssl_bypass(uri) : Net::HTTP.get(uri)
    ranking_doc = Nokogiri::HTML(ranking_html)
    ranking_table = ranking_doc.css("aside table.silver table")[0]
    header = []
    if ranking_table.present?
      ranking_table.css("tr")[1..].each do |tr|
        if tr.css("th").count > 1
          header = []
          tr.css("th")[0..].each do |th|
            header << th.text
            colspan = th.attributes["colspan"].andand.value.to_i
            next unless colspan > 1

            (2..colspan).each do
              header << ""
            end
          end
        elsif tr.css("td").count.positive?
          rang = g = v = rp = quote = points = innings = gd = bed = hs = hb = mp = player_fl_name = nil
          header.each_with_index do |h, ii|
            case h
            when /\A(rang)\z/i
              rang = tr.css("td")[ii].text.to_i
            when /\A(rp)\z/i
              rp = tr.css("td")[ii].text.to_i
            when /\A(name|teilnehmer)\z/i
              player_fl_name = tr.css("td")[ii].css("a").text.gsub(nbsp, " ").gsub(/\s*\((.*)\)/, "").strip
            when /\A(g|f)\z/i
              g = tr.css("td")[ii].text.to_i
            when /\A(v)\z/i
              v = tr.css("td")[ii].text.to_i
            when /\A(quote)\z/i
              quote = tr.css("td")[ii].text
            when /\A(punkte)\z/i
              points = tr.css("td")[ii].text.to_i
            when /\A(aufn\.)\z/i
              innings = tr.css("td")[ii].text.to_i
            when /\A(hb)\z/i
              hb = tr.css("td")[ii].text
            when /\A(bed)\z/i
              bed = tr.css("td")[ii].text.gsub(",", ".").to_f.round(2)
            when /\A(gd)\z/i
              gd = tr.css("td")[ii].text.gsub(",", ".").to_f.round(2)
            when /\A(hs)\z/i
              hs = tr.css("td")[ii].text
            when /\A(mp)\z/i
              mp = tr.css("td")[ii].text.to_i
            end
          end
          if player_fl_name =~ /\//
            names = player_fl_name.split(/\//).map(&:strip)
            player_fl_name = player_list[names.join(" ")].present? ? names.join(" ") : names.reverse.join(" ")
          end
          seeding = seedings.where(player: player_list[player_fl_name][0]).first if player_list[player_fl_name].present?
          if seeding.blank?
            Rails.logger.info("===== scrape ===== seeding of player #{player_fl_name} should exist!")
          else
            seeding.assign_attributes(
              data: {
                "result" =>
                  { "Gesamtrangliste" =>
                      { "Rang" => rang,
                        "RP" => rp,
                        "Name" => player_list[player_fl_name][0].fullname,
                        "Club" => player_list[player_fl_name].andand[1].andand.shortname,
                        "Punkte" => points,
                        "Frames" => frame_points,
                        "Aufn." => innings,
                        "G" => g,
                        "V" => v,
                        "Quote" => quote,
                        "GD" => gd,
                        "BED" => bed,
                        "HS" => hs,
                        "HB" => hb }.compact }
              }
            )
            seeding.region_id = region.id
            seeding.save if seeding.changed?
          end
        end
      rescue StandardError => e
        Rails.logger.info("===== scrape ===== something wrong: #{e} #{e.backtrace}")
      end
    end

    self.region_id = region.id
    save! if changed?
    tc.save! if tc.changed?
  rescue StandardError => e
    Tournament.logger.info "===== scrape =====  StandardError #{e}:\n#{e.backtrace.to_a.join("\n")}"
    reset_tournament
  end

  def fix_location_from_location_text
    location_name = location_text.split("\n").first
    return unless location_name.present?
    return unless location.present?

    nil unless /#{location_name}/.match?(location.synonyms)
    # done
  end

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)

    # Only call data_will_change! if the data actually changed
    if h != data
      data_will_change!
      self.data = JSON.parse(h.to_json)
    end
    # save!
  end

  def reset_tournament
    Tournament.logger.info "[reset_tournament]..."
    # called from state machine only
    # use direct only for testing purposes
    table_monitors_to_update = []
    if tournament_monitor.present?
      table_monitors_to_update = tournament_monitor.table_monitors.to_a
      tournament_monitor.destroy
      table_monitors_to_update.each do |tm|
        tm.reload.reset_table_monitor
      end
    end
    unless (organizer.is_a? Club) || (id.present? && id > Seeding::MIN_ID)
      seedings.where("seedings.id >= #{Seeding::MIN_ID}").destroy_all
      unless new_record?
        reload.seedings.order(:position).each_with_index do |s, ix|
          s.unprotected = true
          s.position = ix + 1
          s.save
          s.unprotected = false
        end
      end
    end
    games.where("games.id >= #{Game::MIN_ID}").destroy_all
    unless new_record? || (id.present? && id > Seeding::MIN_ID)
      self.unprotected = true

      # Only call data_will_change! if data is not already empty
      if data.present? && data != {}
        data_will_change!
      end

      assign_attributes(tournament_plan_id: nil, state: "new_tournament", data: {})
      save
      self.unprotected = false
      # finish_mode_selection!
      # reload
      # reorder_seedings
    end
    
    # Broadcast teaser updates nach Reset um Views zu aktualisieren
    # TableMonitors haben jetzt keine games mehr (game_id = nil)
    Tournament.logger.info "[reset_tournament] Broadcasting teasers for cleared table monitors"
    table_monitors_to_update.each do |tm|
      TableMonitorJob.perform_later(tm.id, "teaser")
    end
    
    Tournament.logger.info "state:#{state}...[reset_tournament]"
  end

  # Berechnet und cached die effektiven Rankings für alle Spieler
  # Wird beim Finalisieren der Seedings aufgerufen (tournament_seeding_finished)
  # Nur für lokale Tournaments (id >= MIN_ID), nicht für ClubCloud-Records
  def calculate_and_cache_rankings
    return unless organizer.is_a?(Region) && discipline.present?
    return unless id.present? && id >= Tournament::MIN_ID # Nur für lokale Tournaments

    Tournament.logger.info "[calculate_and_cache_rankings] for local tournament #{id}"

    # Berechne Rankings basierend auf effective_gd (wie in define_participants)
    current_season = Season.current_season
    seasons = Season.where('id <= ?', current_season.id).order(id: :desc).limit(3).reverse

    # Lade alle Rankings für die Disziplin und Region
    all_rankings = PlayerRanking.where(
      discipline_id: discipline_id,
      season_id: seasons.pluck(:id),
      region_id: organizer_id
    ).to_a

    # Gruppiere nach Spieler
    rankings_by_player = all_rankings.group_by(&:player_id)

    # Berechne effective_gd für jeden Spieler (neueste Saison zuerst)
    player_effective_gd = {}
    rankings_by_player.each do |player_id, rankings|
      gd_values = seasons.map do |season|
        ranking = rankings.find { |r| r.season_id == season.id }
        ranking&.gd
      end
      # effective_gd = aktuellste Saison || Saison davor || Saison davor-1
      effective_gd = gd_values[2] || gd_values[1] || gd_values[0]
      player_effective_gd[player_id] = effective_gd if effective_gd.present?
    end

    # Sortiere Spieler nach effective_gd (absteigend) und ermittle Rang
    sorted_players = player_effective_gd.sort_by { |player_id, gd| -gd }
    player_rank = {}
    sorted_players.each_with_index do |(player_id, gd), index|
      player_rank[player_id] = index + 1
    end

    # Speichere in data Hash
    data_will_change!
    self.data ||= {}
    self.data['player_rankings'] = player_rank
    save!

    Tournament.logger.info "[calculate_and_cache_rankings] cached #{player_rank.size} player rankings"
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

  # Guard für reset_tournament - nur club_admin oder system_admin dürfen zurücksetzen
  def admin_can_reset_tournament?
    current_user = User.current || PaperTrail.request.whodunnit
    return true if current_user.blank? # Beim Initialisieren gibt es keinen User

    user = current_user.is_a?(User) ? current_user : User.find_by(id: current_user)
    user&.club_admin? || user&.system_admin?
  end

  def date_str
    return unless date.present?

    "#{date.to_s(:db)}#{" - #{end_date.to_date.to_s(:db)}" if end_date.present?}"
  end

  def name
    title || shortname
  end

  # Prüft ob dieses Turnier ClubCloud-Ergebnisse hat
  # ClubCloud-Daten sind erkennbar an:
  # - Seedings mit id < MIN_ID (50_000_000)
  # - data["result"] ist gefüllt
  def has_clubcloud_results?
    # Da data als text serialisiert ist (nicht jsonb), müssen wir die Ruby-Objekte laden
    seedings.where("seedings.id < ?", Seeding::MIN_ID).any? do |seeding|
      seeding.data.present? && seeding.data["result"].present? && seeding.data["result"].is_a?(Hash) && seeding.data["result"].any?
    end
  end

  # ===== Automatic Table Reservation for Heating Control =====
  
  # Calculates the required number of tables for the tournament
  # based on the tournament plan or participant count
  # Public method to allow external calls and testing
  def required_tables_count
    return 0 unless location.present? && discipline.present?
    
    # Count participants (excluding no-shows)
    participant_count = seedings.where.not(state: 'no_show').count
    return 0 if participant_count.zero?
    
    # Try to get from tournament plan if available
    if tournament_plan.present? && tournament_plan.tables.present? && tournament_plan.tables > 0
      return tournament_plan.tables
    end
    
    # Check if there are multiple possible tournament plans for this participant count
    possible_plans = TournamentPlan.joins(discipline_tournament_plans: :discipline)
                                   .where(discipline_tournament_plans: {
                                     players: participant_count,
                                     discipline_id: discipline_id
                                   })
                                   .where.not(tables: nil)
    
    if possible_plans.any?
      # Return the maximum table count from all possible plans
      return possible_plans.maximum(:tables) || fallback_table_count(participant_count)
    end
    
    # Fallback: estimate based on participant count
    fallback_table_count(participant_count)
  end
  
  # Creates a Google Calendar reservation for the tournament tables
  # Returns the event response or nil if creation failed
  # Public method to allow external calls and testing
  def create_table_reservation
    return nil unless location.present? && discipline.present? && date.present?
    
    tables_needed = required_tables_count
    return nil if tables_needed.zero?
    
    # Find suitable tables with heaters (tpl_ip_address present)
    # Filter by discipline's table_kind and order by ID ascending
    available_tables = location.tables
                               .joins(:table_kind)
                               .where(table_kinds: { id: discipline.table_kind_id })
                               .where.not(tpl_ip_address: nil)
                               .order(:id)
                               .limit(tables_needed)
    
    return nil if available_tables.empty?
    
    # Build table list string (e.g., "T1, T2, T3" or "T1-T3")
    table_names = available_tables.map(&:name).sort_by { |name| name.match(/\d+/)[0].to_i }
    table_string = format_table_list(table_names)
    
    # Build event summary based on tournament details
    summary = build_event_summary(table_string)
    
    # Calculate event times
    start_time = calculate_start_time
    end_time = calculate_end_time
    
    # Create Google Calendar event
    create_google_calendar_event(summary, start_time, end_time)
  end

  private

  def parse_table_tr(region, frame1_lines, frame_points, frame_result, frames, gd, group, hb,
                     header, hs, mp, innings, nbsp, no,
                     player_list, playera_fl_name, playerb_fl_name,
                     points, result, result_lines, result_url, td_lines, tr)
    if tr.css("th").count == 1
      group_ = tr.css("th").text.gsub(nbsp, " ").strip
      if group.present? && no.present? && group_.present? && group_ != 0 && group != group_
        handle_game(region, frame_result, frames, gd, group, hs, hb, mp, innings, no, player_list, playera_fl_name,
                    playerb_fl_name, frame_points, points, result)
        result = nil
        playera_fl_name = nil
        playerb_fl_name = nil
        frames = []
        frame_points = []
        innings = []
        hs = []
        gd = []
        hb = []
        points = []
        frame_result = []
        no = nil
      end
      group = group_
    elsif tr.css("th").count > 1
      header = tr.css("th").map(&:text)
    elsif tr.css("td").count.positive?
      no_ = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
      if no.present? && no_.present? && no_ != 0 && no != no_
        handle_game(region, frame_result, frames, gd, group, hs, hb, mp, innings, no, player_list, playera_fl_name,
                    playerb_fl_name, frame_points, points, result)
        result = nil
        playera_fl_name = nil
        playerb_fl_name = nil
        frames = []
        frame_points = []
        innings = []
        hs = []
        gd = []
        hb = []
        points = []
        frame_result = []
        no = nil
      end
      td_lines += 1
      case header
      when %w[Partie Begegnung Partien Erg.]
        no, playera_fl_name, playerb_fl_name, result, result_lines =
          variant0(nbsp, points, result_lines, tr)
      when %w[Partie Begegnung Frames HB Erg.]
        no, playera_fl_name, playerb_fl_name, result =
          result_with_frames(frame_points, hb, nbsp, tr)
        result_lines += 1
      when %w[Partie Begegnung Partien Ergebnis]
        no, playera_fl_name, playerb_fl_name, result =
          result_with_parties(nbsp, points, tr)
        result_lines += 1
      when %w[Partie Begegnung Erg.]
        no, playera_fl_name, playerb_fl_name, result =
          result_with_party(nbsp, points, tr)
        result_lines += 1
      when %w[Partie Frame Begegnung HB Erg.]
        frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines =
          result_with_party_variant(frame1_lines, frame_points, frame_result, frames, hb, nbsp, result_lines, tr)
      when ["Partie", "Frame", "Begegnung", "Aufn.", "", "", "Erg."]
        frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines =
          result_with_party_variant2(frame1_lines, frame_result, frames, innings, nbsp, points, result_lines, tr)
      when %w[Partie Frame Begegnung Erg.]
        if tr.css("td").count == 2 && tr.css("td")[0].text.gsub(nbsp, " ").strip == "Ergebnis:"
          result_lines += 1
          result = tr.css("td")[1].text.gsub(nbsp, " ").strip
        elsif tr.css("td").count == 4
          frames << tr.css("td")[1].text.to_i
          frame_result << tr.css("td")[3].text.gsub(nbsp, " ").strip
        else
          frame1_lines, no, playera_fl_name, playerb_fl_name =
            variant2(frame1_lines, frame_result, frames, nbsp, points, tr)
        end
      when %w[Partie Begegnung Planzeit]
        frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines, innings, points, gd, hs =
          variant3(frame1_lines, frames, header, nbsp, innings, points, gd, hs, result_lines, result_url, tr)
      when %w[Partie Begegnung Pkt. Aufn. HS GD Erg.], %w[Partie Begegnung Punkte Aufn. HS GD Erg.]
        no, playera_fl_name, playerb_fl_name, result, result_lines =
          Variant4(gd, hs, innings, nbsp, points, result_lines, tr)

      when ["Partie", "Begegnung", "Pkt.", "Aufn.", "", "", "Erg."]
        no, playera_fl_name, playerb_fl_name, result, result_lines = variant5(innings, nbsp, points, result_lines, tr)

      when %w[Partie Frame Begegnung Pkt. Aufn. HS GD Erg.]
        # TODO: Begegnung??
        if tr.css("td").count >= 3
          frame1_lines, frame_result, no =
            variant6(frame1_lines, frames, gd, hs, innings, nbsp, points, tr)
        end
      when %w[Partie Begegnung Aufn. HS GD Erg.], %w[Partie Begegnung Aufn. HS GD Ergebnis]
        no, playera_fl_name, playerb_fl_name, result, result_lines =
          variant7(gd, hs, innings, nbsp, points, result_lines, tr)
      when %w[Partie Begegnung GD Erg.]
        no, playera_fl_name, playerb_fl_name, result, result_lines =
          variant8(gd, nbsp, points, result_lines, tr)
      else
        Rails.logger.info("===== scrape ===== unknown header #{header.inspect}")
      end
    end
    [frame1_lines, frame_points, frame_result, frames, gd, group, hb, header, hs, mp, innings, nbsp, no, player_list,
     playera_fl_name, playerb_fl_name, points, result, result_lines, result_url, td_lines, tr]
  end

  def variant0(nbsp, points, result_lines, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[4].text.gsub(nbsp, " ").strip
    result = tr.css("td")[5].text.gsub(nbsp, " ").strip
    result_lines += 1
    [no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def variant8(gd, nbsp, points, result_lines, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[2].text.gsub(nbsp, " ").strip
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    gd << tr.css("td")[4].text.gsub(nbsp, " ").strip
    result = tr.css("td")[5].text.gsub(nbsp, " ").strip
    result_lines += 1
    [no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def variant7(gd, hs, innings, nbsp, points, result_lines, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[2].text.gsub(nbsp, " ").strip
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    innings << tr.css("td")[4].text.gsub(nbsp, " ").strip
    hs << tr.css("td")[5].text.gsub(nbsp, " ").strip
    gd << tr.css("td")[6].text.gsub(nbsp, " ").strip
    result = tr.css("td")[7].text.gsub(nbsp, " ").strip
    result_lines += 1
    [no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def variant6(frame1_lines, frames, gd, hs, innings, nbsp, points, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    frames << tr.css("td")[1].text.to_i
    frame1_lines += 1 if tr.css("td")[1].text.to_i == 1
    points << tr.css("td")[3].text.gsub(nbsp, " ").strip
    innings << tr.css("td")[4].text.gsub(nbsp, " ").strip
    hs << tr.css("td")[5].text.gsub(nbsp, " ").strip
    gd << tr.css("td")[6].text.gsub(nbsp, " ").strip
    frame_result = tr.css("td")[7].text.gsub(nbsp, " ").strip
    [frame1_lines, frame_result, no]
  end

  def variant5(innings, nbsp, points, result_lines, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[4].text.gsub(nbsp, " ").strip
    innings << tr.css("td")[5].text.gsub(nbsp, " ").strip
    result = tr.css("td")[8].text.gsub(nbsp, " ").strip
    result_lines += 1
    [no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def Variant4(gd, hs, innings, nbsp, points, result_lines, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[4].text.gsub(nbsp, " ").strip
    innings << tr.css("td")[5].text.gsub(nbsp, " ").strip
    hs << tr.css("td")[6].text.gsub(nbsp, " ").strip
    gd << tr.css("td")[7].text.gsub(nbsp, " ").strip
    result = tr.css("td")[8].text.gsub(nbsp, " ").strip
    result_lines += 1
    [no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def variant3(frame1_lines, frames, header, nbsp, innings, points, gd, hs, result_lines, result_url, tr)
    if tr.css("td").count == 3 && tr.css("td")[0].text.gsub(nbsp, " ").strip =~ /(Endergebnis|Ergebnis):/
      result_lines += 1
      result = tr.css("td")[1].text.gsub(nbsp, " ").strip
    elsif tr.css("td").count == 5 && tr.css("td")[0].text.gsub(nbsp, " ").strip =~ /(Frame|Satz)/
      frames << tr.css("td")[0].text.to_i
      frame1_lines += 1
      points << tr.css("td")[2].text.gsub(nbsp, "").strip
    elsif tr.css("td").count == 5
      no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
      playera_fl_name = (tr.css("td")[1].inner_html.gsub(%r{</?strong>}, "").split("<br>")[0].presence || "Freilos").gsub(
        /\s*\((.*)\)/, ""
      )
      a1, b1, c1 = tr.css("td")[1].inner_html.gsub(%r{</?strong>},
                                                   "").split("<br>")[1].andand.gsub(nbsp, " ").andand.match(%r{<i>(?:HS: (\d+); )?Aufn.: (\d+); Ø: ([\d.]+)</i>}).andand[1..]
      playerb_fl_name = (tr.css("td")[3].inner_html.gsub(%r{</?strong>}, "").split("<br>")[0].presence || "Freilos").gsub(
        /\s*\((.*)\)/, ""
      )
      a2, b2, c2 = tr.css("td")[3].inner_html.gsub(%r{</?strong>},
                                                   "").split("<br>")[1].andand.gsub(nbsp, " ").andand.match(%r{<i>(?:HS: (\d+); )?Aufn.: (\d+); Ø: ([\d.]+)</i>}).andand[1..]
      hs << "#{a1}/#{a2}"
      innings << "#{b1}/#{b2}"
      gd << "#{c1}/#{c2}"
      points << tr.css("td")[2].text.gsub(nbsp, "").strip
    else
      Rails.logger.info("===== scrape ===== Error: unexpected input #{header.inspect}, #{tr.inspect}, url: #{result_url}")
    end
    [frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines, innings, points, gd, hs]
  end

  def variant2(frame1_lines, frame_result, frames, nbsp, points, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    frames << tr.css("td")[1].text.to_i
    frame1_lines += 1 if tr.css("td")[1].text.to_i == 1
    playera_fl_name = (tr.css("td")[2].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    playerb_fl_name = (tr.css("td")[4].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[3].text.gsub(nbsp, " ").strip
    frame_result << tr.css("td")[5].text.gsub(nbsp, " ").strip
    [frame1_lines, no, playera_fl_name, playerb_fl_name]
  end

  def result_with_party_variant2(frame1_lines, frame_result, frames, innings, nbsp, points, result_lines, tr)
    if tr.css("td").count == 2 && tr.css("td")[0].text.gsub(nbsp, " ").strip == "Ergebnis:"
      result_lines += 1
      result = tr.css("td")[1].text.gsub(nbsp, " ").strip
    elsif tr.css("td").count == 7
      frames << tr.css("td")[1].text.to_i
      innings << tr.css("td")[3].text.gsub(nbsp, " ").strip
      frame_result << tr.css("td")[6].text.gsub(nbsp, " ").strip
    else
      no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
      frames << tr.css("td")[1].text.to_i
      frame1_lines += 1 if tr.css("td")[1].text.to_i == 1
      playera_fl_name = (tr.css("td")[2].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
      playerb_fl_name = (tr.css("td")[4].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
      innings << tr.css("td")[5].text.gsub(nbsp, " ").strip
      points << tr.css("td")[3].text.gsub(nbsp, " ").strip
      frame_result << tr.css("td")[8].text.gsub(nbsp, " ").strip
    end
    [frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def result_with_party_variant(frame1_lines, frame_points, frame_result, frames, hb, nbsp, result_lines, tr)
    if tr.css("td").count == 2 && tr.css("td")[0].text.gsub(nbsp, " ").strip == "Ergebnis:"
      result_lines += 1
      result = tr.css("td")[1].text.gsub(nbsp, " ").strip
    elsif tr.css("td").count == 5
      frames << tr.css("td")[1].text.to_i
      hb << tr.css("td")[3].text.gsub(nbsp, " ").strip
      frame_result << tr.css("td")[4].text.gsub(nbsp, " ").strip
    else
      no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
      frames << tr.css("td")[1].text.to_i
      frame1_lines += 1 if tr.css("td")[1].text.to_i == 1
      playera_fl_name = (tr.css("td")[2].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
      playerb_fl_name = (tr.css("td")[4].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
      # innings << tr.css('td')[5].text.gsub(nbsp, " ").strip
      frame_points << tr.css("td")[3].text.gsub(nbsp, " ").strip
      hb << tr.css("td")[5].text.gsub(nbsp, " ").strip
      frame_result << tr.css("td")[6].text.gsub(nbsp, " ").strip
    end
    [frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def result_with_party(nbsp, points, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[2].text.gsub(nbsp, " ").strip
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    result = tr.css("td")[4].text.gsub(nbsp, " ").strip
    [no, playera_fl_name, playerb_fl_name, result]
  end

  def result_with_parties(nbsp, points, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[2].text.gsub(nbsp, " ").strip
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    result = tr.css("td")[4].text.gsub(nbsp, " ").strip
    [no, playera_fl_name, playerb_fl_name, result]
  end

  def result_with_frames(frame_points, hb, nbsp, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    frame_points << tr.css("td")[4].text.gsub(nbsp, " ").strip
    hb << tr.css("td")[5].text.gsub(nbsp, " ").strip
    result = tr.css("td")[6].text.gsub(nbsp, " ").strip
    [no, playera_fl_name, playerb_fl_name, result]
  end

  def parse_table_td(ix, logger, region, season, seeding, state_ix, states, td)
    l_state_ix = state_ix
    if td.css("div").present?
      lastname, firstname, club_str =
        td.css("div").text.gsub(nbsp, " ").strip
          .match(/(.*),\s*(.*)\s*\((.*)\)/).to_a[1..].map(&:strip)
      _player, club, _seeding, _state_ix = Player.fix_from_shortnames(lastname, firstname, season, region,
                                                                      club_str, self,
                                                                      true, true, ix)
      if club.present?
        season_participations = SeasonParticipation.joins(:player).joins(:club).joins(:season).where(
          seasons: { id: season.id }, players: { fl_name: "#{firstname} #{lastname}".strip }
        )
        if season_participations.count == 1
          season_participation = season_participations.first
          player = season_participation&.player
          if player.present?
            unless season_participation&.club_id == club.id
              real_club = season_participations.first&.club
              if real_club.present?
                logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} not active in Club #{club_str} [#{club.ba_id}], Region #{region.shortname}, season #{season.name}!"
                logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - Fixed: Player #{lastname}, #{firstname} is active in Club #{real_club.shortname} [#{real_club.ba_id}], Region #{real_club.region&.shortname}, season #{season.name}!"

                _sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player.id, season.id,
                                                                                      real_club.id) ||
                  SeasonParticipation.create(player_id: player.id, season_id: season.id, club_id: real_club.id,
                                             position: ix + 1)
                unless _sp.present?
                  sp = SeasonParticipation.new(player_id: player.id, season_id: season.id, club_id: real_club.id,
                                               position: ix + 1)
                  sp.region_id = region.id
                  sp.save
                end
              end
            end
            seeding = Seeding.find_by_player_id_and_tournament_id(player.id, id)
            unless seeding.present?
              seeding = Seeding.new(player_id: player.id, tournament: self, position: position)
              seeding.region_id = region.id
              seeding.save
            end
            seeding_ids.delete(seeding.id)
          end
        elsif season_participations.count.zero?
          players = Player.where(type: nil).where(firstname:, lastname:)
          if players.count.zero?
            logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - Fatal: Player #{lastname}, #{firstname} not found in club #{club_str} [#{club.ba_id}] , Region #{region.shortname}, season #{season.name}! Not found anywhere - typo?"

            # Use PlayerFinder to prevent duplicates
            player_fixed = Player.find_or_create_player(
              firstname: firstname,
              lastname: lastname,
              club_id: club.id,
              region_id: region.id,
              season_id: season.id,
              allow_create: true
            )

            if player_fixed.present?
              logger.info "==== scrape ==== [scrape_tournaments] Player #{lastname}, #{firstname} (ID: #{player_fixed.id}) found/created for club #{club_str} [#{club.ba_id}]"
            else
              logger.error "==== scrape ==== [scrape_tournaments] Failed to find/create player #{lastname}, #{firstname}"
            end
            sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id,
                                                                                 club.id)
            unless sp.present?
              sp = SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
              records_to_tag |= Array(sp)
            end
            seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, id)
            unless seeding.present?
              seeding = Seeding.new(player_id: player_fixed.id, tournament: self, position: position)
              seeding.region_id = region.id
              seeding.save
            end
            seeding_ids.delete(seeding.id)
          elsif players.count == 1
            player_fixed = players.first
            if player_fixed.present?
              logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} is not active in Club #{club_str} [#{club.ba_id}], region #{region.shortname} and season #{season.name}"
              sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id,
                                                                                   club.id)
              unless sp.present?
                sp = SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
                records_to_tag |= Array(sp)
              end
              logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - fixed: Player #{lastname}, #{firstname} set active in Club #{club_str} [#{club.ba_id}], region #{region.shortname} and season #{season.name}"
              seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, id)
              unless seeding.present?
                seeding = Seeding.new(player_id: player_fixed&.id, tournament: self, position: position)
                seeding.region_id = region.id
                seeding.save
              end
              seeding_ids.delete(seeding.id)
            end
          elsif players.count > 1
            clubs_str = players.map(&:club).map do |c|
              "#{c.shortname} [#{c.ba_id}]"
            end
            club_fixed_str = players.map(&:club).map do |c|
              "#{c.shortname} [#{c.ba_id}]"
            end.first
            logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - Fatal: Ambiguous: Player #{lastname}, #{firstname} not active everywhere but exists in Clubs [#{clubs_str}] "
            logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - temporary fix: Assume Player #{lastname}, #{firstname} is active in Clubs [#{club_fixed_str}] "
            player_fixed = players.first
            if player_fixed.present? && club.present?
              sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id,
                                                                                   club.id)
              unless sp.present?
                sp = SeasonParticipation.new(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
                sp.region_id = region.id
                sp.save
              end
              seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, id)
              unless seeding.present?
                seeding = Seeding.new(player_id: player_fixed&.id, tournament: self, position: position)
                seeding.region_id = region.id
                seeding.save
              end
              seeding_ids.delete(seeding.id)
            end
          end
        elsif season_participations.map(&:club_id).uniq.include?(club.id)
          # (ambiguous clubs)
          season_participation = season_participations.where(club_id: club.id).first
          player = season_participation&.player
          if player.present?
            _seeding = Seeding.find_by_player_id_and_tournament_id(player.id, id)
            unless _seeding.present?
              _seeding = Seeding.new(player_id: player.id, tournament_id: id)
              _seeding.region_id = region.id
              _seeding.save
            end
          end
        else
          logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} is not active in Club[#{club.ba_id}] #{club_str}, region #{region.shortname} and season #{season.name}"
          fixed_season_participation = season_participations.last
          fixed_club = fixed_season_participation.club
          fixed_player = fixed_season_participation.player
          logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - fixed: Player #{lastname}, #{firstname} playing for Club[#{fixed_club.ba_id}] #{fixed_club.shortname}, region #{fixed_club.region.shortname} and season #{season.name}"
          sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(fixed_player.id, season.id,
                                                                               fixed_club.id)
          unless sp.present?
            sp = SeasonParticipation.new(player_id: fixed_player.id, season_id: season.id,
                                         club_id: fixed_club.id)
            sp.region_id = region.id
            sp.save
          end
          seeding = Seeding.find_by_player_id_and_tournament_id(fixed_player.id, id)
          unless seeding.present?
            seeding = Seeding.new(player_id: fixed_player.id, tournament_id: id)
            seeding.region_id = region.id
            seeding.save
          end
          seeding_ids.delete(seeding.id)
        end
      else
        logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - fatal: Club #{club_str}, region #{region.shortname} not found!! Typo?"
        fixed_club = region.clubs.new(name: club_str, shortname: club_str)
        fixed_club.region_id = region.id
        fixed_club.save
        fixed_player = fixed_club.players.new(firstname:, lastname:)
        fixed_player.region_id = region.id
        fixed_player.save
        fixed_club.update(ba_id: 999_000_000 + fixed_club.id)
        fixed_player.update(ba_id: 999_000_000 + fixed_player.id)
        sp = SeasonParticipation.create(player_id: fixed_player.id, season_id: season.id, club_id: fixed_club.id)
        sp.region_id = region.id
        sp.save
        logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - temporary fix: Club #{club_str} created in region #{region.shortname}"
        logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - temporary fix: Player #{lastname}, #{firstname} playing for Club #{club_str}"
        seeding = Seeding.find_by_player_id_and_tournament_id(fixed_player.id, id)
        unless seeding.present?
          seeding = Seeding.new(player_id: fixed_player&.id, tournament: self, position: position)
          seeding.region_id = region.id
          seeding.save
        end
        seeding_ids.delete(seeding.id)
      end
    elsif /X/.match?(td.text.gsub(nbsp, " ").strip)
      if seeding.present?
        seeding.update_attribute(:ba_state, states[l_state_ix])
      else
        logger.info "==== scrape ==== [scrape_tournaments] Fatal 501 - seeding nil???"
        Kernel.exit(501)
      end
    end
  end

  def handle_game(region, frame_result, frames, gd, group, hs, hb, mp, innings, no, player_list, playera_fl_name, playerb_fl_name,
                  frame_points, points, result)
    # Skip games where both players are "Freilos" (bye games) - these shouldn't be created
    # Check if both players are "Freilos" or both are missing from player_list
    playera_missing = playera_fl_name == "Freilos" || !player_list[playera_fl_name].present?
    playerb_missing = playerb_fl_name == "Freilos" || !player_list[playerb_fl_name].present?
    if playera_missing && playerb_missing
      Rails.logger.info "Skipping bye game (Freilos vs Freilos) for tournament #{id}, seqno #{no}, group #{group}"
      return
    end
    game = games.where(seqno: no, gname: group).first
    region_id = region.id
    data = if frames.count > 1
             frame_data = []
             frames.each_with_index do |_frame, ix|
               frame_data << {
                 "Frame" => frames[ix],
                 "Punkte" => points[ix].presence || frame_points[ix],
                 "Aufn." => innings[ix],
                 "HS" => hs[ix],
                 "HB" => hb[ix],
                 "Durchschnitt" => gd[ix],
                 "FrameResult" => frame_result[ix]
               }.compact
             end
             {
               "Gruppe" => group,
               "Partie" => no,
               "Heim" => player_list[playera_fl_name].andand[0].andand.fullname,
               "Gast" => player_list[playerb_fl_name].andand[0].andand.fullname,
               "Disziplin" => discipline.andand.name,
               "Ergebnis" => result
             }.compact.merge(frames: frame_data)
           else
             {
               "Gruppe" => group,
               "Partie" => no,
               "Frame" => frames[0],
               "Heim" => player_list[playera_fl_name].andand[0].andand.fullname.presence || "Freilos",
               "Gast" => player_list[playerb_fl_name].andand[0].andand.fullname.presence || "Freilos",
               "Disziplin" => discipline.andand.name,
               "Punkte" => points[0].presence || frame_points[0],
               "MP" => mp[0],
               "Aufn." => innings[0],
               "HS" => hs[0],
               "HB" => hb[0],
               "Durchschnitt" => gd[0],
               "FrameResult" => frame_result[0],
               "Ergebnis" => result
             }.compact
           end
    if game.present?
      game.assign_attributes(tournament_id: self.id,
                             tournament_type: "Tournament",
                             data: data,
                             seqno: no,
                             gname: group)
      if game.changed?
        game.region_id = region_id
        game.save!
      end
    else
      game = Game.new(
        tournament_id: self.id,
        tournament_type: "Tournament",
        data: data,
        seqno: no,
        gname: group
      )
      game.region_id = region_id
      game.save! if game.changed?
    end
    unless game.game_participations.empty? &&
      player_list[playera_fl_name].present? &&
      player_list[playerb_fl_name].present?
      return
    end

    gp = game.game_participations.new(
      player_id: player_list[playera_fl_name][0].id,
      role: "Heim",
      data:
        { "results" =>
            { "Gr." => group,
              "Ergebnis" => points[0].to_s.split(":")[0].andand.strip,
              "Aufnahme" => innings[0].to_s.split("/")[0].andand.strip,
              "GD" => gd[0].to_s.split("/")[0].andand.strip,
              "HS" => hs[0].to_s.split("/")[0].andand.strip }.compact },
      result: points[0].to_s.split(":")[0].andand.strip,
      innings: innings[0].to_s.split("/")[0].andand.strip,
      gd: gd[0].to_s.split("/")[0].andand.strip,
      hs: hs[0].to_s.split("/")[0].andand.strip
    )
    gp.region_id = region_id
    gp.save! if gp.changed?
    gp = game.game_participations.new(
      player_id: player_list[playerb_fl_name][0].id,
      role: "Gast",
      data:
        { "results" =>
            { "Gr." => group,
              "Ergebnis" => points[0].to_s.split(":")[1].andand.strip,
              "Aufnahme" => innings[0].to_s.split("/")[1].andand.strip,
              "GD" => gd[0].to_s.split("/")[1].andand.strip,
              "HS" => hs[0].to_s.split("/")[1].andand.strip }.compact },
      result: points[0].to_s.split(":")[1].andand.strip,
      innings: innings[0].to_s.split("/")[1].andand.strip,
      gd: gd[0].to_s.split("/")[1].andand.strip,
      hs: hs[0].to_s.split("/")[1].andand.strip
    )
    gp.region_id = region_id
    gp.save! if gp.changed?
  end

  def before_all_events
    Tournament.logger.info "[tournament] #{aasm.current_event.inspect}"
  end

  private
  
  def fallback_table_count(participant_count)
    # Fallback estimation: half of participants (rounded up)
    # assuming simultaneous matches in first round
    (participant_count / 2.0).ceil
  end
  
  def format_table_list(table_names)
    return "" if table_names.empty?
    
    # Extract table numbers
    numbers = table_names.map { |name| name.match(/\d+/)[0].to_i }.sort
    
    # Check if consecutive
    if numbers == (numbers.first..numbers.last).to_a
      # Consecutive: use range format
      "T#{numbers.first}-T#{numbers.last}"
    else
      # Non-consecutive: list all
      numbers.map { |n| "T#{n}" }.join(", ")
    end
  end
  
  def build_event_summary(table_string)
    # Format: "T1, T2, T3 NDM Cadre 35/2 Klasse 5-6"
    # or: "T1-T3 Clubmeisterschaft 8-Ball"
    parts = [table_string]
    
    # Add tournament title or shortname
    if shortname.present?
      parts << shortname
    elsif title.present?
      parts << title
    end
    
    # Add discipline name if present
    if discipline.present?
      parts << discipline.name
    end
    
    # Add player class if present
    if player_class.present?
      parts << "Klasse #{player_class}"
    end
    
    parts.join(" ")
  end
  
  def calculate_start_time
    tournament_date = date
    
    # Use starting_at from tournament_cc if available, otherwise default to 11:00
    if tournament_cc.present? && tournament_cc.starting_at.present?
      start_hour = tournament_cc.starting_at.hour
      start_minute = tournament_cc.starting_at.min
    else
      start_hour = 11
      start_minute = 0
    end
    
    # Combine date with time
    Time.zone.local(
      tournament_date.year,
      tournament_date.month,
      tournament_date.day,
      start_hour,
      start_minute,
      0
    ).utc.iso8601
  end
  
  def calculate_end_time
    tournament_date = date
    
    # End time: 20:00
    Time.zone.local(
      tournament_date.year,
      tournament_date.month,
      tournament_date.day,
      20,
      0,
      0
    ).utc.iso8601
  end
  
  def create_google_calendar_event(summary, start_time, end_time)
    return nil unless Rails.application.credentials.dig(:google_service, :private_key).present?
    
    begin
      # Setup Google API credentials
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
      
      scopes = %w[https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/calendar.events]
      authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(google_creds_json),
        scope: scopes
      )
      
      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = authorizer
      calendar_id = Rails.application.credentials[:location_calendar_id]
      
      event_object = Google::Apis::CalendarV3::Event.new(
        summary: summary,
        start: {
          date_time: start_time,
          time_zone: "UTC"
        },
        end: {
          date_time: end_time,
          time_zone: "UTC"
        }
      )
      
      response = service.insert_event(calendar_id, event_object)
      Rails.logger.info "Tournament ##{id}: Created calendar reservation '#{summary}' (Event ID: #{response.id})"
      response
    rescue StandardError => e
      Rails.logger.error "Tournament ##{id}: Failed to create calendar reservation: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end
  end
end
