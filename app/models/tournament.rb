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

  serialize :remarks, Hash

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

  def reset_tournament
    logger.info "[reset_tournament]..."
    # called from state machine only
    # use direct only for testing purposes

    tournament_monitor.andand.destroy
    seedings.update_all(position: nil)
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
