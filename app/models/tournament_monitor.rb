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
  include TournamentMonitorSupport
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
        val = val * 1000.0 + results[k.to_s].to_f
      end
      val
    end.reverse
  end

  def player_id_from_ranking(rule_str, opts = {})
    ordered_ranking_nos = opts[:ordered_ranking_nos]
    if (mm = rule_str.match(/\((.*)\)\.rk(\d)$/).presence)
      # rule_str: "(g1.rk4 + g2.rk4 +g3.rk4).rk2"
      rank_from_group_ranks(mm, opts)
    elsif (mm = rule_str.match(/\((.*)\)\.rk-rand-(\d+)-(\d+)$/).presence)
      # rule_str: "(g1.rk4 + g2.rk4 +g3.rk4).rk-rand-1-4"
      random_from_group_ranks(mm, ordered_ranking_nos, rule_str)
    elsif (mm = rule_str.match(/g(\d+).(\d+)$/).presence)
      group_rank(mm)
    elsif (mm=rule_str.match(/(rule\d+)/)).presence
      player_id_from_ranking(opts[:executor_params]["rules"][mm[1]], opts)
    else
      ko_ranking(rule_str)
    end
  rescue StandardError => e
    Tournament.logger.info "player_id_from_ranking(#{rule_str}) #{e} #{e.backtrace&.join("\n")}"
    nil
  end

  def next_seqno
    # select max(seqno) from tournament.games
    tournament.games.where("games.id >= #{Game::MIN_ID}").where.not(seqno: nil).map(&:seqno).max.to_i + 1
  end

  def self.distribute_to_group(players, ngroups, group_sizes = nil)
    groups = {}
    (1..ngroups).each do |group_no|
      groups["group#{group_no}"] = []
    end
    
    # Wenn group_sizes gegeben: Verwende size-aware Algorithmus
    if group_sizes.present? && group_sizes.is_a?(Array)
      return distribute_with_sizes(players, ngroups, group_sizes)
    end
    
    # NBV-konformer Algorithmus (abhängig von Gruppenzahl)
    # 2 Gruppen: Zig-Zag/Serpentinen (1→G1, 2→G2, 3→G2, 4→G1, 5→G1, ...)
    # 4+ Gruppen: Round-Robin (1→G1, 2→G2, 3→G3, 4→G4, 5→G1, ...)
    
    if ngroups == 2
      # Zig-Zag für 2 Gruppen (NBV T07, T10, etc.)
      group_ix = 1
      direction_right = true
      players.each do |player|
        player_id = player.is_a?(Integer) ? player : player.id
        groups["group#{group_ix}"] << player_id
        
        if direction_right
          group_ix += 1
          if group_ix > ngroups
            direction_right = false
            group_ix = ngroups
          end
        else
          group_ix -= 1
          if group_ix <= 0
            direction_right = true
            group_ix = 1
          end
        end
      end
    else
      # Round-Robin für 3+ Gruppen (NBV T14, T27, T28, etc.)
      players.each_with_index do |player, index|
        player_id = player.is_a?(Integer) ? player : player.id
        group_no = (index % ngroups) + 1
        groups["group#{group_no}"] << player_id
      end
    end
    
    groups
  rescue StandardError => e
    Tournament.logger.info "distribute_to_group(#{players}, #{ngroups}) #{e} #{e.backtrace&.join("\n")}"
    {}
  end
  
  # Verteilt Spieler auf Gruppen mit spezifischen Gruppengrößen
  # NBV-Algorithmus: Round-Robin, dann größere Gruppen von hinten auffüllen
  def self.distribute_with_sizes(players, ngroups, group_sizes)
    groups = {}
    group_fill_count = {}
    
    (1..ngroups).each do |group_no|
      groups["group#{group_no}"] = []
      group_fill_count[group_no] = 0
    end
    
    # Phase 1: Standard Round-Robin bis alle Gruppen mindestens min_size erreichen
    min_size = group_sizes.min
    players_for_phase1 = min_size * ngroups
    
    players[0...players_for_phase1].each_with_index do |player, index|
      player_id = player.is_a?(Integer) ? player : player.id
      group_no = (index % ngroups) + 1
      groups["group#{group_no}"] << player_id
      group_fill_count[group_no] += 1
    end
    
    # Phase 2: Restliche Spieler gehen in größere Gruppen (von hinten nach vorne!)
    remaining_players = players[players_for_phase1..-1] || []
    
    # Finde Gruppen die noch Platz haben (sortiert nach Gruppe, absteigend!)
    groups_with_space = (1..ngroups).to_a.reverse.select do |gn|
      max_size = group_sizes[gn - 1]
      group_fill_count[gn] < max_size
    end
    
    remaining_players.each_with_index do |player, index|
      player_id = player.is_a?(Integer) ? player : player.id
      
      if groups_with_space.any?
        target_group = groups_with_space.shift  # Nimm erste verfügbare (von hinten!)
        groups["group#{target_group}"] << player_id
        group_fill_count[target_group] += 1
        
        # Wenn Gruppe jetzt voll: entferne sie aus der Liste
        max_size = group_sizes[target_group - 1]
        groups_with_space << target_group if group_fill_count[target_group] < max_size
      else
        Tournament.logger.warn "distribute_with_sizes: Konnte Spieler #{players_for_phase1 + index + 1} nicht zuordnen!"
      end
    end
    
    groups
  end

  private

  def ko_ranking(rule_str)
    g_no, _game_no, rk_no = rule_str.match(/^(?:(?:fg|g)(\d+)|sl|rule|vf|hf|af|qf|fin|p<\d+(?:\.\.|-)\d+>)(\d+)?\.rk(\d)$/)[1..3]
    if g_no.present?
      case rule_str
      when /^sl/
        tournament.seedings.where("id > #{Seeding::MIN_ID}").to_a[rk_no.to_i - 1].player_id
      when /^fg/
        TournamentMonitor.ranking(data["rankings"]["endgames"]["group#{g_no}"],
                                  order: (
                                    if tournament.handicap_tournier?
                                      %i[points
                                         bg_p]
                                    else
                                      %i[points
                                         gd]
                                    end))[rk_no.to_i - 1].andand[0]
      when /^g/
        TournamentMonitor.ranking(data["rankings"]["groups"]["group#{g_no}"],
                                  order: (
                                    if tournament.handicap_tournier?
                                      %i[points
                                         bg_p]
                                    else
                                      %i[points
                                         gd]
                                    end))[rk_no.to_i - 1].andand[0]
      else
        nil
      end
    elsif (m = rule_str.match(/^(vf|hf|rule|af|qf|fin|p<\d+(?:-|\.\.)\d+>)(\d+)?/))
      TournamentMonitor.ranking(data["rankings"]["endgames"]["#{m[1]}#{m[2]}"],
                                order: (
                                  if tournament.handicap_tournier?
                                    %i[points
                                       bg_p]
                                  else
                                    %i[points
                                       gd]
                                  end))[rk_no.to_i - 1].andand[0]

    elsif /^sl/.match?(rule_str)
      tournament.seedings.where("id > #{Seeding::MIN_ID}").to_a[rk_no.to_i - 1].player_id
    end
  end

  def group_rank(match)
    group_no = match[1]
    seeding_index = match[2].to_i
    seeding_scope = if tournament
                       .seedings
                       .where("seedings.id >= #{Seeding::MIN_ID}")
                       .count.positive?
                      "seedings.id >= #{Seeding::MIN_ID}"
                    else
                      "seedings.id< #{Seeding::MIN_ID}"
                    end
    groups = TournamentMonitor.distribute_to_group(
      tournament.seedings.where(seeding_scope).order(:position).map(&:player), 
      tournament.tournament_plan.ngroups,
      tournament.tournament_plan.group_sizes  # NEU: Gruppengrößen aus executor_params
    )
    # distribute_to_group now returns player IDs directly, not player objects
    groups["group#{group_no}"][seeding_index - 1]
  end

  def random_from_group_ranks(match, ordered_ranking_nos, rule_str)
    ordered_ranking_nos[rule_str] ||= (match[2].to_i..match[3].to_i).to_a.shuffle
    inter_group_order = if tournament.gd_has_prio?
                          tournament.handicap_tournier? ? %i[bg_p points] : %i[gd points]
                        else
                          (tournament.handicap_tournier? ? %i[points bg_p] : %i[points gd])
                        end
    players = match[1]
    rank = ordered_ranking_nos[rule_str].pop
    subset = {}
    members = players.split(/\s*\+\s*/)
    members.each do |member|
      g_no, _game_no, rk_no = member.match(/^(?:(?:fg|g)(\d+)|sl|rule|vf|hf|af|qf|fin
|p<\d+(?:\.\.|-)\d+>)(\d+)?\.rk(\d)$/)[1..3]
      rk =
        case member
        when /^sl/
          tournament.seedings.where("id > #{Seeding::MIN_ID}").to_a[rk_no.to_i - 1].player_id
        when /^fg/
          TournamentMonitor.ranking(data["rankings"]["endgames"]["group#{g_no}"],
                                    order: (
                                      if tournament.handicap_tournier?
                                        %i[points
                                           bg_p]
                                      else
                                        %i[points gd]
                                      end))[rk_no.to_i - 1]
        when /^g/
          TournamentMonitor.ranking(data["rankings"]["groups"]["group#{g_no}"],
                                    order: (
                                      if tournament.handicap_tournier?
                                        %i[points
                                           bg_p]
                                      else
                                        %i[points gd]
                                      end))[rk_no.to_i - 1]
        else
          nil
        end
      subset.merge!(Hash[*rk])
    end
    TournamentMonitor.ranking(subset, order: inter_group_order)[rank.to_i - 1].andand[0]
  end

  def rank_from_group_ranks(match, opts={})
    inter_group_order = if tournament.gd_has_prio?
                          tournament.handicap_tournier? ? %i[bg_p points] : %i[gd points]
                        else
                          (tournament.handicap_tournier? ? %i[points bg_p] : %i[points gd])
                        end
    players = match[1]
    rank = match[2]
    subset = {}
    members = players.split(/\s*\+\s*/)
    members.each do |member|
      if member =~ /rule\d/
        member = member + ".rk1"
      end
      g_no, _game_no, rk_no = member.match(/^(?:(?:fg|g)(\d+)|sl|vf|hf|af|qf|rule|fin|p<\d+(?:\.\.|-)\d+>)(\d+)?\.rk(\d)$/)[1..3]
      rk =
        case member
        when /^sl/
          tournament.seedings.where("id > #{Seeding::MIN_ID}").to_a[rk_no.to_i - 1].player_id
        when /^fg/
          TournamentMonitor.ranking(data["rankings"]["endgames"]["group#{g_no}"],
                                    order: (
                                      if tournament.handicap_tournier?
                                        %i[points
                                           bg_p]
                                      else
                                        %i[points gd]
                                      end))[rk_no.to_i - 1]
        when /^g/
          TournamentMonitor.ranking(data["rankings"]["groups"]["group#{g_no}"],
                                    order: (
                                      if tournament.handicap_tournier?
                                        %i[points
                                           bg_p]
                                      else
                                        %i[points gd]
                                      end))[rk_no.to_i - 1]
        when /^rule/
          player_id= player_id_from_ranking(opts[:executor_params]["rules"][member.split(".")[0]], opts)
          [player_id, data["rankings"]["groups"]["total"][player_id]]
        else
          next
        end
      subset.merge!(Hash[*rk])
    end
    TournamentMonitor.ranking(subset, order: inter_group_order)[rank.to_i - 1].andand[0]
  end

  def before_all_events
    Tournament.logger.info "[tournament_monitor] #{aasm.current_event.inspect}"
  end
end
