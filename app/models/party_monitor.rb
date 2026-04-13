# == Schema Information
#
# Table name: party_monitors
#
#  id                             :bigint           not null, primary key
#  allow_follow_up                :boolean          default(TRUE), not null
#  color_remains_with_set         :boolean          default(TRUE), not null
#  data                           :text
#  ended_at                       :datetime
#  fixed_display_left             :string
#  kickoff_switches_with          :string
#  sets_to_play                   :integer          default(1), not null
#  sets_to_win                    :integer          default(1), not null
#  started_at                     :datetime
#  state                          :string
#  team_size                      :integer          default(1), not null
#  time_out_stoke_preparation_sec :integer          default(45)
#  time_out_warm_up_first_min     :integer          default(5)
#  time_out_warm_up_follow_up_min :integer          default(3)
#  timeout                        :integer          default(0), not null
#  timeouts                       :integer
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  party_id                       :integer
#
class PartyMonitor < ApplicationRecord
  include ApiProtector # (usage forbidden from api server)
  include AASM

  belongs_to :party, class_name: "Party", optional: true
  has_many :table_monitors, as: :tournament_monitor, class_name: "TableMonitor", dependent: :nullify

  alias_method :tournament, :party
  serialize :data, coder: JSON, type: Hash
  cattr_accessor :allow_change_tables

  before_save :log_state_change
  before_save :set_paper_trail_whodunnit

  DEBUG = Rails.env != "production"

  # Broadcast changes in realtime with Hotwire
  after_create_commit lambda {
                        broadcast_prepend_later_to :party_monitors, partial: "party_monitors/index",
                          locals: {party_monitor: self}
                      }
  # after_update_commit -> {
  #   broadcast_replace_later_to self
  # }
  after_destroy_commit -> { broadcast_remove_to :party_monitors, target: dom_id(self, :index) }

  aasm column: "state" do
    state :seeding_mode, initial: true, after_enter: [:reset_party_monitor]
    state :table_definition_mode
    state :next_round_seeding_mode
    state :ready_for_next_round
    state :playing_round
    state :round_result_checking_mode
    state :party_result_checking_mode
    state :party_result_reporting_mode
    state :closed
    before_all_events :before_all_events
    event :prepare_next_round do
      transitions from: %i[seeding_mode round_result_checking_mode], to: :table_definition_mode
    end
    event :enter_next_round_seeding do
      transitions from: [:table_definition_mode], to: :next_round_seeding_mode
    end
    event :finish_round_seeding_mode do
      transitions from: :next_round_seeding_mode, to: :ready_for_next_round
    end
    event :start_round do
      transitions from: %i[ready_for_next_round], to: :playing_round
    end
    event :finish_round do
      transitions from: %i[playing_round], to: :round_result_checking_mode
    end
    event :finish_party do
      transitions from: %i[round_result_checking_mode], to: :party_result_checking_mode
    end
    event :close_party do
      transitions from: %i[party_result_checking_mode], to: :closed
    end

    event :end_of_party do
      transitions to: :closed
    end
  end

  def fixed_display_left?
    "playera"
  end

  def log_state_change
    return unless state_changed?
    return unless DEBUG

    Tournament.logger.info "[PartyMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}"
    Rails.logger.info "[PartyMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}" if DEBUG
  end

  def data
    HashWithIndifferentAccess.new(read_attribute(:data))
  end

  def data=(val)
    write_attribute(:data, val.to_hash)
  end

  def reset_party_monitor
    PartyMonitor::TablePopulator.new(self).reset_party_monitor
  end

  def initialize_table_monitors
    PartyMonitor::TablePopulator.new(self).initialize_table_monitors
  end

  def do_placement(new_game, r_no, t_no, row = nil, row_nr = nil)
    PartyMonitor::TablePopulator.new(self).do_placement(new_game, r_no, t_no, row, row_nr)
  end

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    self.data = JSON.parse(h.to_json)
    # save!
  end

  # TODO: duplicate code from TournamentMonitor
  def current_round
    data["current_round"].presence || 1
  end

  def current_round!(round)
    data_will_change!
    deep_merge_data!(current_round: round)
    save
  end

  def incr_current_round!
    data_will_change!
    deep_merge_data!(current_round: current_round + 1)
    save
  end

  def decr_current_round!
    data_will_change!
    deep_merge_data!(current_round: current_round - 1)
    save
  end

  def states
    aasm.states
  end

  def events
    aasm.events
  end

  def report_result(table_monitor)
    PartyMonitor::ResultProcessor.new(self).report_result(table_monitor)
  end

  def finalize_round
    PartyMonitor::ResultProcessor.new(self).finalize_round
  end

  def finalize_game_result(table_monitor)
    PartyMonitor::ResultProcessor.new(self).finalize_game_result(table_monitor)
  end

  # duplicate of tournament_monitor#accumulate_results
  #
  def accumulate_results
    PartyMonitor::ResultProcessor.new(self).accumulate_results
  end

  def update_game_participations(tabmon)
    PartyMonitor::ResultProcessor.new(self).update_game_participations(tabmon)
  end

  # TODO: duplicate from tournament_monitor#all_table_monitors_finished?
  def all_table_monitors_finished?
    !(
      table_monitors.joins(:game).map(&:state) & %w[warmup warmup_a warmup_b
        match_shootout playing final_set_score set_over]
    ).present?
  end

  # TODO: room for optimization!
  def get_attribute_by_gname(gname, key_)
    key = key_.to_sym
    seqno = gname.split("-")[0].to_i
    type = gname.split("-").drop(1).join("-")
    ix = data["rows"].find_index { |row| row["seqno"] == seqno && row["type"] == type }
    ix.present? ? data["rows"][ix][key] : nil
  rescue => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  # TODO: room for optimization!
  def get_game_plan_attribute_by_gname(gname, key_)
    key = key_.to_sym
    seqno = gname.split("-")[0].to_i
    type = gname.split("-").drop(1).join("-")
    data = party.league.game_plan.data
    ix = data["rows"].find_index { |row| row[:seqno] == seqno && row[:type] == type }
    ix.present? ? data["rows"][ix][key] : nil
  end

  private

  def before_all_events
    Rails.logger.info "[party_monitor] #{aasm.current_event.inspect}"
  end
end
