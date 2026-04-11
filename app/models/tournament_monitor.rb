# frozen_string_literal: true

require "csv"

# == Schema Information
#
# Table name: tournament_monitors
#
#  id                     :bigint           not null, primary key
#  allow_follow_up        :boolean          default(TRUE), not null
#  allow_overflow         :boolean
#  balls_goal             :integer
#  color_remains_with_set :boolean          default(TRUE), not null
#  data                   :text
#  fixed_display_left     :string
#  innings_goal           :integer
#  kickoff_switches_with  :string
#  sets_to_play           :integer          default(1), not null
#  sets_to_win            :integer          default(1), not null
#  state                  :string
#  team_size              :integer          default(1), not null
#  timeout                :integer          default(0), not null
#  timeouts               :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  tournament_id          :integer
#
# Foreign Keys
#
#  fk_rails_...  (tournament_id => tournaments.id)
#
class TournamentMonitor < ApplicationRecord
  include TournamentMonitorState
  include ApiProtector

  cattr_accessor :current_admin
  cattr_accessor :allow_change_tables

  include AASM

  before_save :set_paper_trail_whodunnit

  belongs_to :tournament
  has_many :table_monitors, as: :tournament_monitor, class_name: "TableMonitor", dependent: :nullify
  has_many :was_table_monitors, as: :tournament_monitor, foreign_key: :prev_tournament_monitor_id,
                                class_name: "TableMonitor", dependent: :nullify

  serialize :data, coder: JSON, type: Hash

  before_save :log_state_change
  before_save :set_paper_trail_whodunnit

  # Broadcast Status-Update wenn State sich ändert
  after_update_commit :broadcast_status_update, if: :saved_change_to_state?

  DEBUG = Rails.env != "production"

  def log_state_change
    return unless state_changed?

    return unless DEBUG

    Tournament.logger.info "[TournamentMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}"
  end

  aasm column: "state" do
    state :new_tournament_monitor, initial: true, after_enter: [:do_reset_tournament_monitor]
    state :playing_groups, before_enter: :debug_log
    # state :evaluating_results, before_enter: :debug_log, :after_enter => [:populate_tables]
    state :playing_finals, before_enter: :debug_log
    state :tournament_finished
    state :party_result_reporting_mode
    state :closed
    before_all_events :before_all_events
    event :start_playing_groups do
      transitions from: %i[new_tournament_monitor playing_groups], to: :playing_groups
    end
    event :start_playing_finals do
      transitions from: %i[new_tournament_monitor playing_groups playing_finals], to: :playing_finals
    end
    event :report_game_result do
      # TODO: transitions from: :playing_groups,
    end

    event :end_of_tournament do
      transitions to: :closed
    end
  end

  # def initialize(attributes = nil, options = nil)
  #   super
  # end

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    self.data = JSON.parse(h.to_json)
    # save!
  end

  def debug_log
    self
  end

  def current_round
    data["current_round"].presence || 1
  end

  def current_round!(round)
    data_will_change!
    data["current_round"] = round
    update(data: data)
  end

  def incr_current_round!
    data_will_change!
    data["current_round"] = current_round + 1
    update(data: data)
  end

  def decr_current_round!
    data_will_change!
    data["current_round"] = current_round - 1
    update(data: data)
  end

  # def table_monitors_ready_and_populated
  #   Tournament.logger.info "[tmon-table_monitors_ready_and_populated]..."
  #   res = table_monitors_ready? && table_monitors_populated?
  #   Tournament.logger.info "returns #{res}...[tmon-table_monitors_ready_and_populated]"
  #   return res
  # end

  def self.ranking(hash, opts = {})
    hash.to_a.sort_by do |_player, results|
      val = 0
      opts[:order].each do |k|
        val = (val * 1000.0) + results[k.to_s].to_f
      end
      val
    end.reverse
  end

  def player_id_from_ranking(rule_str, opts = {})
    TournamentMonitor::RankingResolver.new(self).player_id_from_ranking(rule_str, opts)
  end

  # Delegation wrappers — result pipeline lives in TournamentMonitor::ResultProcessor
  def report_result(table_monitor)
    TournamentMonitor::ResultProcessor.new(self).report_result(table_monitor)
  end

  def update_game_participations(tabmon)
    TournamentMonitor::ResultProcessor.new(self).update_game_participations(tabmon)
  end

  def update_game_participations_for_game(game, data)
    TournamentMonitor::ResultProcessor.new(self).send(:update_game_participations_for_game, game, data)
  end

  def accumulate_results
    TournamentMonitor::ResultProcessor.new(self).accumulate_results
  end

  def update_ranking
    TournamentMonitor::ResultProcessor.new(self).update_ranking
  end

  def write_game_result_data(table_monitor)
    TournamentMonitor::ResultProcessor.new(self).send(:write_game_result_data, table_monitor)
  end

  def next_seqno
    # select max(seqno) from tournament.games
    tournament.games.where("games.id >= #{Game::MIN_ID}").where.not(seqno: nil).map(&:seqno).max.to_i + 1
  end

  # Delegation wrappers — table population lives in TournamentMonitor::TablePopulator
  def do_reset_tournament_monitor
    TournamentMonitor::TablePopulator.new(self).do_reset_tournament_monitor
  end

  def populate_tables
    TournamentMonitor::TablePopulator.new(self).populate_tables
  end

  def initialize_table_monitors
    TournamentMonitor::TablePopulator.new(self).initialize_table_monitors
  end

  # Delegation wrappers — algorithm lives in TournamentMonitor::PlayerGroupDistributor
  def self.distribute_to_group(players, ngroups, group_sizes = nil)
    TournamentMonitor::PlayerGroupDistributor.distribute_to_group(players, ngroups, group_sizes)
  end

  def self.distribute_with_sizes(players, ngroups, group_sizes)
    TournamentMonitor::PlayerGroupDistributor.distribute_with_sizes(players, ngroups, group_sizes)
  end

  private

  # Delegation wrapper — kept for characterization tests that call via send(:ko_ranking)
  # Algorithm lives in TournamentMonitor::RankingResolver
  def ko_ranking(rule_str)
    TournamentMonitor::RankingResolver.new(self).send(:ko_ranking, rule_str)
  end

  def before_all_events
    Tournament.logger.info "[tournament_monitor] #{aasm.current_event.inspect}"
  end

  # Broadcast Status-Update für Tournament View
  def broadcast_status_update
    return unless tournament.present?

    TournamentStatusUpdateJob.perform_later(tournament)
  end
end
