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
  
  # International associations
  belongs_to :international_tournament, optional: true
  
  # Polymorphe Video Association
  has_many :videos, as: :videoable, dependent: :nullify

  scope :active_manual_assignment, -> { where(state: "tournament_started").where(manual_assignment: true) }
  scope :international, -> { where(type: 'InternationalTournament') }
  scope :upcoming, -> { where('date >= ?', Date.today).order(date: :asc) }
  scope :in_year, ->(year) { year.present? ? where('EXTRACT(YEAR FROM date) = ?', year) : all }

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

  # Quick 260507-jfe — Extracts the player_class token (e.g. "5", "III")
  # from a German-federation tournament title. Returns nil if the title is blank
  # or encodes no class from Discipline::PLAYER_CLASS_ORDER.
  #
  # Called from Region#scrape_tournaments_data and Region#scrape_upcoming_tournaments
  # at Tournament.create(...) time, alongside the existing is_handicap derivation.
  # Pure / idempotent — keine DB-Zugriffe. Kann überall aufgerufen werden.
  #
  # Design: PLAYER_CLASS_ORDER in deklarierter Reihenfolge durchlaufen (7 6 5 4 3 2 1 I II III).
  # Zwei Erkennungsformen je Token:
  #   1. Marker-Form: "Klasse 5", "Kl. III", "KK 7", "Kl.1" — Groß-/Kleinschreibung ignoriert.
  #      "Kl." darf direkt am Token kleben (kein Whitespace nötig); andere Marker brauchen \s+.
  #   2. Standalone-trailing-Form: Titel endet auf "... 5" oder "... III" mit Wortgrenze,
  #      z.B. "Cadre 47/2 I". Verhindert Matches in Jahreszahlen ("2024") oder Brüchen ("47/2").
  def self.parse_player_class_from_title(title)
    return nil if title.blank?

    Discipline::PLAYER_CLASS_ORDER.each do |token|
      escaped = Regexp.escape(token)
      # Marker-Form: "Klasse 5", "Kl. III", "KK 7", "Kl.1" (Punkt trennt — Whitespace optional)
      return token if title =~ /(?:\bKl\.\s*|\b(?:Klasse|Kl|KK)\s+)#{escaped}\b/i
      # Standalone-trailing-Form: Titel endet auf Token mit führendem Whitespace
      return token if title =~ /(?:\s)#{escaped}\s*\z/
    end
    nil
  end

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
    # UI-03 D-10: Auto-advance ist jetzt der einheitliche Default — der Rundenwechsel
    # erfolgt immer automatisch, sobald das letzte Spiel einer Runde am Scoreboard
    # bestätigt ist. Die admin_controlled-Spalte bleibt (D-11) für Kompatibilität mit
    # globalen Records, hat aber keine funktionale Wirkung mehr.
    true
  end

  def match_location_from_location_text
    lt = location_text
    name, _address, _zipcode, _city, _tel = lt.split('\n')
    Location.find_by_synonyms(name)
  end

  def scrape_single_tournament_public(opts = {})
    Tournament::PublicCcScraper.call(tournament: self, opts: opts)
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

  # Delegation zu Tournament::RankingCalculator — Logik dort extrahiert
  def calculate_and_cache_rankings
    Tournament::RankingCalculator.new(self).calculate_and_cache_rankings
  end

  def reorder_seedings
    Tournament::RankingCalculator.new(self).reorder_seedings
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
  # Returns available tables with heaters for this tournament's discipline
  # Considers both global tables (tpl_ip_address in tables) and 
  # local tables (tpl_ip_address in table_locals)
  def available_tables_with_heaters(limit: nil)
    return Table.none unless location.present? && discipline.present?
    
    query = location.tables
                    .joins(:table_kind)
                    .left_joins(:table_local)
                    .where(table_kinds: { id: discipline.table_kind_id })
                    .where("(tables.id >= ? AND tables.tpl_ip_address IS NOT NULL) OR (tables.id < ? AND table_locals.tpl_ip_address IS NOT NULL)", 
                           Table::MIN_ID, Table::MIN_ID)
                    .order(:id)
    
    query = query.limit(limit) if limit
    query
  end

  def create_table_reservation
    Tournament::TableReservationService.call(tournament: self)
  end

  private

  def before_all_events
    Tournament.logger.info "[tournament] #{aasm.current_event.inspect}"
  end

  def fallback_table_count(participant_count)
    # Fallback estimation: half of participants (rounded up)
    # assuming simultaneous matches in first round
    (participant_count / 2.0).ceil
  end
end
