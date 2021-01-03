# == Schema Information
#
# Table name: t_tournaments
#
#  id                             :bigint           not null, primary key
#  accredation_end                :datetime
#  age_restriction                :string
#  ba_state                       :string
#  balls_goal                     :integer
#  data                           :text
#  date                           :datetime
#  end_date                       :datetime
#  handicap_tournier              :boolean
#  innings_goal                   :integer
#  last_ba_sync_date              :datetime
#  location                       :text
#  modus                          :string
#  organizer_type                 :string
#  plan_or_show                   :string
#  player_class                   :string
#  shortname                      :string
#  single_or_league               :string
#  state                          :string
#  time_out_stoke_preparation_sec :integer          default(45)
#  time_out_warm_up_first_min     :integer          default(5)
#  time_out_warm_up_follow_up_min :integer          default(3)
#  title                          :string
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  ba_id                          :integer
#  discipline_id                  :integer
#  location_id                    :integer
#  organizer_id                   :integer
#  region_id                      :integer
#  season_id                      :integer
#  tournament_id                  :bigint
#  tournament_plan_id             :integer
#
# Indexes
#
#  index_t_tournaments_on_ba_id         (ba_id) UNIQUE
#  index_t_tournaments_on_foreign_keys  (title,season_id,region_id)
#
require 'open-uri'
require 'net/http'

class TTournament < ApplicationRecord

  include AASM
  has_paper_trail

  belongs_to :tournament
  belongs_to :tournament_plan, optional: true
  has_many :seedings, -> { order(position: :asc) }, class_name: "TSeeding", foreign_key: :t_tournament_id
  has_many :games, dependent: :destroy, class_name: "TGame", foreign_key: :t_tournament_id
  has_one :tournament_monitor
  has_many :tournament_tables
  belongs_to :tournament_location, class_name: "TLocation", foreign_key: :t_location_id, optional: true

  serialize :data, Hash

  def self.init(tournament)
    tt = tournament.t_tournament
    if tt.blank?
      tt = tournament.create_t_tournament
      tt.seedings.create(
        tournament.seedings.map{|s| {player_id: s.player_id}}
      )
    end
    return tt
  end

  validates_each :data do |record, attr, value|
    table_ids = Array(record.send(attr)[:table_ids])
    if table_ids.present?
      incomplete = table_ids.length != record.tournament_plan.andand.tables.to_i
      heterogen = Table.where(id: table_ids).all.map(&:location_id).uniq.length > 1
      inconsistent = table_ids != table_ids.uniq
      record.errors.add(attr, I18n.t('table_assignments_incomplete')) if incomplete
      record.errors.add(attr, I18n.t('table_assignments_heterogen')) if heterogen
      record.errors.add(attr, I18n.t('table_assignments_inconsistent')) if inconsistent
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
    logger.info "[initialize_tournament_monitor]..."
    TournamentMonitor.transaction do
      # http = TCPServer.new nil, 80
      # DNSSD.announce http, 'carambus server'
      # Setting.key_set_val(:carambus_server_status, "ready to accept connections from scoreboards")
      games = []
      tm = tournament_monitor || create_tournament_monitor()
      # tm = TournamentMonitor.find_or_create_by!(
      #     tournament_id: self.id
      # )
      # reload
      logger.info "state:#{state}...[initialize_tournament_monitor]"
    rescue Exception => e
      logger.info "...[initialize_tournament_monitor] Exception #{e}:\n#{e.backtrace.join("\n")}"
      reset_tournament
      Rails.logger.error("Some problem occurred when creating TournamentMonitor - Tournament resetted")

    end

  end

  def reset_tournament
    logger.info "[reset_tournament]..."
    # called from state machine only
    # use direct only for testing purposes

    tournament_monitor.andand.destroy
    seedings.update_all(position: nil, data: nil)
    games.destroy_all
    unless new_record?
      update_columns(tournament_plan_id: nil, state: "new_tournament")
      reload
    end
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
