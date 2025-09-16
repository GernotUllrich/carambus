# frozen_string_literal: true

# == Schema Information
#
# Table name: table_monitors
#
#  id                           :bigint           not null, primary key
#  active_timer                 :string
#  copy_from                    :integer
#  current_element              :string           default("pointer_mode"), not null
#  data                         :text
#  ip_address                   :string
#  name                         :string
#  nnn                          :integer
#  panel_state                  :string           default("pointer_mode"), not null
#  prev_data                    :text
#  prev_tournament_monitor_type :string
#  state                        :string
#  timer_finish_at              :datetime
#  timer_halt_at                :datetime
#  timer_start_at               :datetime
#  tournament_monitor_type      :string
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  clock_job_id                 :string
#  game_id                      :integer
#  next_game_id                 :integer
#  prev_game_id                 :integer
#  prev_tournament_monitor_id   :integer
#  timer_job_id                 :string
#  tournament_monitor_id        :integer
#
class TableMonitor < ApplicationRecord
  include ApiProtector
  include CableReady::Broadcaster

  #broadcasts_to ->(table_monitor) { [table_monitor, :table_show2] }, inserts_by: :prepend, updates_by: :replace


  DEBUG = Rails.env != "production"

  cattr_accessor :allow_change_tables

  # the following exist to avoid db access from partials
  cattr_accessor :options
  cattr_accessor :gps
  cattr_accessor :location
  cattr_accessor :tournament
  cattr_accessor :my_table

  serialize :gps, coder: YAML, type: Hash
  serialize :options, coder: YAML, type: Hash

  include AASM
  belongs_to :tournament_monitor, polymorphic: true, optional: true
  belongs_to :game, optional: true
  belongs_to :prev_game, class_name: "Game", optional: true
  belongs_to :prev_tournament_monitor, polymorphic: true, class_name: "TournamentMonitor", optional: true
  has_one :table, dependent: :nullify
  before_save :set_paper_trail_whodunnit
  before_destroy :log_state_change_destroy

  before_create :on_create
  before_save :log_state_change

  delegate :name, to: :table, allow_nil: true

  after_update_commit lambda {
    #broadcast_replace_later_to self
    relevant_keys = (previous_changes.keys - %w[data nnn panel_state pointer_mode current_element])
    get_options!(I18n.locale)
    if tournament_monitor.is_a?(PartyMonitor) &&
      (relevant_keys.include?("state") || state != "playing")
      TableMonitorJob.perform_later(self,
                                    "party_monitor_scores")
    end
    if previous_changes.keys.present? && relevant_keys.present?
      TableMonitorJob.perform_later(self, "table_scores")
    else
      TableMonitorJob.perform_later(self, "teaser")
    end
    TableMonitorJob.perform_later(self, "")
    # broadcast_replace_to self
  }

  def deep_diff(hash_a, hash_b)
    if hash_a.is_a?(Hash)
      (hash_a.keys | hash_b.keys).each_with_object({}) do |k, diff|
        if hash_a[k] != hash_b[k]
          diff[k] = if hash_a[k].is_a?(Hash) && hash_b[k].is_a?(Hash)
                      deep_diff(hash_a[k], hash_b[k])
                    else
                      [hash_a[k], hash_b[k]]
                    end
        end
        diff
      end
    else
      [hash_a, hash_b]
    end
  end

  DEFAULT_ENTRY = {
    "inputs" => "numbers",
    "pointer_mode" => "pointer_mode",
    "shootout" => "start_game",
    "timer" => "play", # depends on state !
    "setup" => "continue",
    "numbers" => "number_field",
    "final_set_score" => "game_state",
    "set_over" => "game_state",
    "final_match_score" => "game_state",
    "ready_for_new_match" => "game_state",
    "show_results" => "game_state",
    "warning" => "ok"
  }.freeze
  NNN = "db" # store nnn in database table_monitor

  serialize :data, coder: JSON, type: Hash
  serialize :prev_data, coder: JSON, type: Hash
  # { "state" => "warmup", # ["warmup", "match_shootout", "playing", "set_over", "final_set_score", "final_match_score"]
  #   "current_set" => 1,
  #   "sets_to_win" => 2,
  #   "sets_to_play" => 3,
  #   "kickoff_switches_with" => "set",
  #   "fixed_display_left": nil,
  #   "color_remains_with_set" => true,
  #   "allow_overflow" => false,
  #   "allow_follow_up" => true,
  #   "current_kickoff_player" => "playera",
  #   "current_left_player" => "playera",
  #   "current_left_color" => "white",
  #   "data" =>
  #     { "innings_goal" => "20",
  #       "playera" =>
  #         { "result" => 0,
  #           "innings" => 0,
  #           "innings_list" => [],
  #           "innings_redo_list" => [],
  #           "hs" => 0,
  #           "gd" => 0.0,
  #           "balls_goal" => "100",
  #           "tc" => 0,
  #           "discipline" => "Freie Partie klein" },
  #       "playerb" =>
  #         { "result" => 0,
  #           "innings" => 0,
  #           "innings_list" => [],
  #           "innings_redo_list" => [],
  #           "hs" => 0,
  #           "gd" => 0.0,
  #           "balls_goal" => "100",
  #           "tc" => 0,
  #           "discipline" => "Freie Partie klein" },
  #       "current_inning" => { "active_player" => "playera", "balls" => 0 },
  #       "timeouts" => 0,
  #       "timeout" => 0, }
  # }

  # TODO: I18n

  aasm column: "state" do
    state :new, initial: true, after_enter: [:reset_table_monitor]
    state :ready
    state :warmup
    state :warmup_a
    state :warmup_b
    state :match_shootout
    state :playing
    state :set_over, after_enter: [:set_game_over]
    state :final_set_score, after_enter: [:set_game_over]
    state :final_match_score, after_enter: [:set_game_over]
    state :ready_for_new_match # previous game result still displayed here - and probably next players
    event :start_new_match, after: :set_start_time do
      transitions from: :ready,
                  to: :warmup
    end
    event :close_match do
      transitions from: %i[playing set_over final_match_score ready_for_new_match], to: :ready_for_new_match
    end
    event :warmup_a do
      transitions from: %i[warmup warmup_b warmup_a],
                  to: :warmup_a
    end
    event :warmup_b do
      transitions from: %i[warmup warmup_a warmup_b],
                  to: :warmup_b
    end
    event :finish_warmup do
      transitions from: %i[match_shootout warmup warmup_a warmup_b],
                  to: :match_shootout
    end
    event :finish_shootout do
      transitions from: :match_shootout, to: :playing
    end
    event :end_of_set do
      transitions from: :playing, to: :set_over
    end
    event :undo do
      transitions from: %i[playing set_over], to: :playing
    end
    event :acknowledge_result do
      transitions from: :set_over, to: :final_set_score
    end
    event :finish_match, after: :set_end_time do
      transitions from: %i[final_set_score], to: :final_match_score
    end
    event :next_set do
      transitions from: %i[set_over final_set_score], to: :playing
    end
    event :ready do
      transitions from: %i[new ready_for_new_match], to: :ready
    end
    event :force_ready do
      transitions to: :ready
    end
  end

  def states
    aasm.states
  end

  def events
    aasm.events
  end

  def internal_name
    if DEBUG
      Rails.logger.info "-----------m6[#{id}]---------->>> internal_name <<<------------------------------------------"
    end
    read_attribute(:name)
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def on_create
    if DEBUG
      Rails.logger.info "-----------m6[#{id}]---------->>> on_create <<<------------------------------------------"
    end
    info = "+++ 8xxx - table_monitor#on_create"
    Rails.logger.info info if DEBUG
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def state_display(locale)
    # Rails.logger.info "-----------m6[#{id}]---------->>> #{"state_display(#{locale})"} <<<-------------------------\
    # -----------------"
    @locale = locale || I18n.default_locale
    @game_or_set = if data["sets_to_play"].to_i > 1
                     I18n.t("table_monitor.set_finished")
                   else
                     I18n.t("table_monitor.final_set_score")
                   end
    if state == "set_over"
      I18n.t("table_monitor.status.set_over",
             game_or_set_finished: @game_or_set,
             wait_check: player_controlled? ? I18n.t("table_monitor.status.wait_check") : "")
    else
      I18n.t("table_monitor.status.#{state}")
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def locked_scoreboard
    state == "set_over" && !player_controlled?
  end

  def log_state_change_destroy
    log_state_change
  end

  def log_state_change
    if DEBUG
      Rails.logger.info "-------------m6[#{id}]-------->>> log_state_change #{self.changes.inspect} <<<\
------------------------------------------"
    end
    if state_changed?
      Tournament.logger.info "[TableMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}" if DEBUG
      Rails.logger.info "[TableMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}" if DEBUG
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def remote_control_detected
    false # TODO: Test remote control and activate here
  end

  def set_game_over
    return unless remote_control_detected

    if DEBUG
      Rails.logger.info "--------------m6[#{id}]------->>> set_game_over <<<------------------------------------------"
    end
    assign_attributes(current_element: "game_state")
    data_will_change!
    save
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def numbers
    Rails.logger.info "-------------m6[#{id}]-------->>> numbers <<<------------------------------------------" if DEBUG
    active_player = data["current_inning"].andand["active_player"]
    nnn_val = data[active_player].andand["innings_redo_list"].andand[-1].to_i
    update(nnn: nnn_val)
    Rails.logger.warn "numbers +++++m6[#{id}]++ C: SUBMIT JOB" if DEBUG
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def update_every_n_seconds(n_secs)
    if DEBUG
      Rails.logger.info "--------------------->>> #{"update_every_n_seconds(#{n_secs})"} <<<\
------------------------------------------"
    end
    TableMonitorClockJob.perform_later(self, n_secs, data["current_inning"]["active_player"],
                                       data[data["current_inning"]["active_player"]].andand["innings_redo_list"].andand[-1].to_i,
                                       data[data["current_inning"]["active_player"]].andand["innings"])
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def player_a_on_table_before
    if DEBUG
      Rails.logger.info "-------------m6[#{id}]-------->>> player_a_on_table_before <<<\
------------------------------------------"
    end
    # TODO: player_a_on_table_before
    false
  end

  def player_b_on_table_before
    if DEBUG
      Rails.logger.info "-------------m6[#{id}]-------->>> player_b_on_table_before <<<\
------------------------------------------"
    end
    # TODO: player_b_on_table_before
    false
  end

  def do_play
    Rails.logger.info "--------------m6[#{id}]------->>> do_play <<<------------------------------------------" if DEBUG
    return unless tournament_monitor&.id.present? || data["timeout"].to_i.positive?

    active_timer = "timeout"
    units = "seconds"
    start_at = Time.now
    delta = tournament_monitor&.tournament&.send(active_timer.to_sym)
                              &.send(units.to_sym) ||
      (data["timeout"].to_i.positive? ? data["timeout"].to_i.seconds : nil)
    finish_at = delta.to_i != 0 && delta.present? ? start_at + delta.to_i : nil
    if timer_halt_at.present? && finish_at.present?
      extend = Time.now.to_i - timer_halt_at.to_i
      start_at = timer_start_at + extend.seconds
      finish_at = timer_finish_at + extend.seconds
    end
    if finish_at.present?
      if DEBUG
        Rails.logger.info "[table_monitor#do_play] m6[#{id}]active_timer, start_at, \
finish_at: #{[active_timer, start_at, finish_at].inspect}"
      end
      update(
        active_timer:,
        timer_halt_at: nil,
        timer_start_at: start_at,
        timer_finish_at: finish_at
      )
      update_every_n_seconds(1)
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def render_innings_list(role)
    if DEBUG
      Rails.logger.info "---------------m6[#{id}]------>>> #{"render_innings_list(#{role})"} <<<\
------------------------------------------"
    end
    innings = data["playera"]["innings"].to_i
    cols = [(innings / 15.0).ceil, 2].max
    show_innings = Array(data[role].andand["innings_list"])
    show_fouls = Array(data[role].andand["innings_foul_list"])
    ret = ["<style>
    table, th, td {
        border: 1px solid black;
        border-collapse: collapse;
    }

    .space-above {
        margin-top: 15px;
    }

    th, td {
    }
    </style><table><thead><tr>"]
    (1..cols).each do |_icol|
      ret << "<th>Aufn</th><th>Pkt</th>#{
        "<th>Foul</th>" if data["playera"].andand["discipline"] == "14.1 endlos"}<th>∑</th>"
    end
    ret << "</tr></thead><tbody>"
    sum = 0
    sums = []
    show_innings.each_with_index do |inning, ix|
      sum += inning + show_fouls[ix]
      sums[ix] = sum
    end
    15.times do |ix|
      ret << "<tr>"
      (1..cols).each_with_index do |_col, icol|
        ret << "<td><span class=\"sm:text-xs lg:text-lg sm:px-2 lg:px-4\">#{ix + 1 + (icol * 15)}</span></td>
<td><span class=\"sm:text-xs lg:text-lg sm:px-2 lg:px-4\">\
#{(ix + (icol * 15)) == sums.length ? "GD" : show_innings[ix + (icol * 15)]}</span></td>
#{
          if data["playera"].andand["discipline"] == "14.1 endlos"
            "<td><span class=\"sm:text-xs lg:text-lg sm:px-2 lg:px-4\">\
#{(ix + (icol * 15)) == sums.length ? "" : show_fouls[ix + (icol * 15)]}</span></td>"
          end}
<td><span class=\"sm:text-xs lg:text-lg sm:px-2 lg:px-4\">#{
          if (ix + (icol * 15)) == sums.length
            format("%0.2f", (sums.last.to_i / innings.to_f))
          elsif (ix + (icol * 15)) == sums.length - 1
            "<strong class=\"text-3vw\">#{sums[ix + (icol * 15)]}</strong>"
          else
            sums[ix + (icol * 15)]
          end}</span></td>"
      end
      ret << "</tr>"
    end
    ret << "</tbody></table>"
    ret.join("\n").html_safe
  rescue StandardError => e
    Rails.logger.info "ERROR:m6[#{id}] #{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def automatic_next_set
    true # TODO: automatic_next_set should be an configurable attribute
  end

  def render_last_innings(last_n, role)
    # debug = DEBUG
    debug = false
    if debug
      Rails.logger.info "-------------m6[#{id}]-------->>> #{"render_last_innings(#{last_n}, #{role})"} <<<\
------------------------------------------"
    end
    player_ix = role == "playera" ? 1 : 2
    show_innings = Array(data[role].andand["innings_list"])
    show_innings_fouls = Array(data[role].andand["innings_foul_list"])
    prefix = ""
    if data["sets_to_play"].to_i > 1
      # S1:0, S2:20
      Array(data["sets"]).each_with_index do |set, ix|
        prefix += "S#{ix + 1}: #{set["Ergebnis#{player_ix}"]}, "
      end
    end
    ret = []
    show_innings.each_with_index do |i, ix|
      ret << ((show_innings_fouls[ix]).zero? ? i.to_s : "#{i},F#{show_innings_fouls[ix]}")
    end
    Array(data[role].andand["innings_redo_list"]).reverse.each_with_index do |i, ix|
      ret << (ix.zero? ? "<strong class=\"border-4 border-solid border-gray-400 p-1\">#{i}</strong>" : i.to_s).to_s
    end
    if ret.length > last_n
      "#{prefix}...#{ret[-last_n..].join(", ")}".html_safe
    else
      (prefix.to_s + ret.join(", ")).html_safe
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if debug
    Tournament.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end

  def warmup_modal_should_be_open?
    # noinspection RubyResolve
    warmup? || warmup_a? || warmup_b?
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def shootout_modal_should_be_open?
    # noinspection RubyResolve
    match_shootout?
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def discipline
    data["playera"].andand["discipline"]
  end

  def numbers_modal_should_be_open?
    # noinspection RubyResolve
    nnn.present? || panel_state == "numbers"
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def get_progress_bar_status(n_bars)
    # debug = DEBUG
    debug = false
    if debug
      Rails.logger.info "------------m6[#{id}]--------->>> #{"get_progress_bar_status(#{n_bars})"} <<<\
------------------------------------------"
    end
    time_counter = green_bars = do_green_bars = do_yellow_bars = do_orange_bars = do_lightred_bars = do_red_bars = 0
    finish = timer_finish_at
    start = timer_start_at
    Rails.logger.info "[table_monitor#get_progress_bar_status] finish, start: #{[finish, start].inspect}" if debug
    if finish.present? && timer_halt_at.present?
      Rails.logger.info "[table_monitor#get_progress_bar_status] finish.present && timer_halt_at.present ..." if debug
      halted = Time.now.to_i - timer_halt_at.to_i
      finish += halted.seconds
      start += halted.seconds
      if debug
        Rails.logger.info "[table_monitor#get_progress_bar_status] halted, finish, start: #{[halted, finish,
                                                                                             start].inspect}"
      end
    end
    if finish.present? && (Time.now < finish)
      Rails.logger.info "[table_monitor#get_progress_bar_status] finish.present && Time.now < finish ..." if debug
      delta_total = (finish - start).to_i
      delta_rest = (finish - Time.now)
      units = active_timer =~ /min$/ ? "minutes" : "seconds"
      if debug
        Rails.logger.info "[table_monitor#get_progress_bar_status] halted, finish, start: #{[delta_total, delta_rest,
                                                                                             units].inspect}"
      end
      if units == "minutes"
        minutes = (delta_rest / 1.send(units)).to_i
        seconds = ((((delta_rest / 1.send(units)) - (delta_rest.to_i / 1.send(units))) *
          100 * 60 / 100).to_i + 100).to_s[-2..]
        time_counter = "#{minutes}:#{seconds}"
      else
        time_counter = (1.0 * delta_rest / 1.send(units)).ceil
      end
      green_bars = [((1.0 * n_bars * delta_rest) / delta_total).ceil, 18].min
      do_bars = [((1.0 * 50 * delta_rest) / delta_total).ceil, 50].min
      do_green_bars = [[do_bars - 40, 10].min, 0].max
      do_yellow_bars = [[do_bars - 30, 10].min, 0].max
      do_orange_bars = [[do_bars - 20, 10].min, 0].max
      do_lightred_bars = [[do_bars - 10, 10].min, 0].max
      do_red_bars = [[do_bars, 10].min, 0].max
      if debug
        Rails.logger.info "[table_monitor#get_progress_bar_status] m6[#{id}]time_counter, green_bars: #{[
          time_counter, green_bars
        ].inspect}"
      end
    end
    if debug
      Rails.logger.info "[table_monitor#get_progress_bar_status] m6[#{id}]return [time_counter, green_bars]: #{[
        time_counter, green_bars
      ].inspect}"
    end
    [time_counter, green_bars, do_green_bars, do_yellow_bars, do_orange_bars, do_lightred_bars, do_red_bars]
  rescue StandardError => e
    Tournament.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}"
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if debug
    raise StandardError unless Rails.env == "production"
  end

  def switch_players
    if DEBUG
      Rails.logger.info "--------------m6[#{id}]------->>> switch_players <<<------------------------------------------"
    end
    if game.present?
      if tournament_monitor&.fixed_display_left?
        deep_merge_data!(
          "current_kickoff_player" => data["current_kickoff_player"] == "playera" ? "playerb" : "playera",
          "current_left_color" => data["current_left_color"] == "white" ? "yellow" : "white",
          "current_inning" => {
            "active_player" => data["current_kickoff_player"] == "playera" ? "playerb" : "playera",
            "balls" => 0
          }
        )
      else
        gps = game.game_participations.order(:id)
        roles = gps.map(&:role).reverse
        gps.to_a.each_with_index do |gp, ix|
          gp.assign_attributes(role: roles[ix])
          gp.save
        end
        ret_a = data["playerb"].dup
        ret_b = data["playera"].dup
        deep_merge_data!({
                           "current_kickoff_player" => "playera",
                           "current_left_player" => "playera",
                           "current_left_color" => "white",
                           "playera" => ret_a,
                           "playerb" => ret_b
                         })
      end
      #save!
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def set_start_time
    if DEBUG
      Rails.logger.info "------------m6[#{id}]--------->>> set_start_time <<<------------------------------------------"
    end
    game.update(started_at: Time.now)
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def set_end_time
    if DEBUG
      Rails.logger.info "-------------m6[#{id}]-------->>> set_end_time <<<------------------------------------------"
    end
    game.update(ended_at: Time.now)
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def assign_game(game_p)
    if DEBUG
      Rails.logger.info "--------------m6[#{id}]------->>> #{"assign_game(#{game_p.attributes.inspect})"} <<<\
------------------------------------------"
    end
    info = "+++ 8c - tournament_monitor#assign_game - game_p"
    Rails.logger.info info if DEBUG
    info = "+++ 8d - tournament_monitor#assign_game - table_monitor"
    Rails.logger.info info if DEBUG
    self.allow_change_tables = tournament_monitor&.allow_change_tables
    tmp_results = game_p.deep_delete!("tmp_results")
    if tmp_results.andand["state"].present?
      info = "+++ 8e - tournament_monitor#assign_game - table_monitor"
      Rails.logger.info info if DEBUG
      state = tmp_results.delete("state")
      deep_merge_data!(tmp_results)
      assign_attributes(game_id: game_p.id, state:)
      save!
    else
      assign_attributes(game_id: game_p.id, state: "ready")
      save!
      reload
      info = "+++ 8f - m6[#{id}]tournament_monitor#assign_game - table_monitor"
      Rails.logger.info info if DEBUG
      initialize_game
      save!
      if %i[ready ready_for_new_match warmup final_match_score
            final_set_score].include?(self.state.to_sym)
        info = "+++ 8g - m6[#{id}]tournament_monitor#assign_game - start_new_match"
        Rails.logger.info info if DEBUG
        # noinspection RubyResolve
        assign_attributes(ip_address: Time.now.to_i.to_s)
        start_new_match!
        finish_warmup! if /shootout/i.match?(game_p.data["player_a"].andand["discipline"])
        # sleep 1.0
      end
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def initialize_game
    Rails.logger.info "--------------------->>> initialize_game <<<------------------------------------------" if DEBUG
    info = "+++ 7 - m6[#{id}]table_monitor#initialize_game"
    Rails.logger.info info if DEBUG
    current_kickoff_player = "playera"
    self.copy_from = nil
    deep_merge_data!({
                       "free_game_form" => tournament_monitor.is_a?(PartyMonitor) ? game.data["free_game_form"] : nil,
                       "balls_on_table" => 15,
                       "balls_counter" => 15,
                       "balls_counter_stack" => [],
                       "extra_balls" => 0,
                       "current_kickoff_player" => current_kickoff_player,
                       "current_left_player" => current_kickoff_player,
                       "current_left_color" => "white",
                       "biathlon_phase" => if tournament_monitor&.tournament.is_a?(Tournament) &&
                         tournament_monitor&.tournament&.discipline&.name == "Biathlon"
                                             "3b"
                                           else
                                             nil
                                           end,
                       "allow_overflow" => if tournament_monitor.is_a?(PartyMonitor)
                                             game.data["allow_overflow"]
                                           else
                                             tournament_monitor&.allow_overflow
                                           end,
                       "kickoff_switches_with" => (
                         if tournament_monitor.is_a?(PartyMonitor)
                           game.data["kickoff_switches_with"]
                         else
                           tournament_monitor&.kickoff_switches_with ||
                             tournament_monitor&.tournament&.kickoff_switches_with
                         end).presence || "set",
                       "allow_follow_up" => if tournament_monitor.is_a?(PartyMonitor)
                                              game.data["allow_follow_up"]
                                            else
                                              tournament_monitor&.allow_follow_up ||
                                                tournament_monitor&.tournament&.allow_follow_up
                                            end,
                       "sets_to_win" => if tournament_monitor.is_a?(PartyMonitor)
                                          game.data["sets_to_win"]
                                        else
                                          tournament_monitor&.sets_to_win ||
                                            tournament_monitor&.tournament&.sets_to_win
                                        end,
                       "sets_to_play" => if tournament_monitor.is_a?(PartyMonitor)
                                           game.data["sets_to_play"]
                                         else
                                           tournament_monitor&.sets_to_play ||
                                             tournament_monitor&.tournament&.sets_to_play
                                         end,
                       "team_size" => if tournament_monitor.is_a?(PartyMonitor)
                                        game.data["team_size"]
                                      else
                                        (tournament_monitor&.team_size ||
                                          tournament_monitor&.tournament&.team_size).presence || 1
                                      end,
                       "innings_goal" => if tournament_monitor.is_a?(PartyMonitor)
                                           game.data["innings_goal"]
                                         else
                                           data["innings_goal"] ||
                                             tournament_monitor&.innings_goal ||
                                             tournament_monitor&.tournament&.innings_goal ||
                                             tournament_monitor&.tournament&.data.andand[:innings_goal]
                                         end,
                       "playera" => {
                         "result" => 0,
                         "innings" => 0,
                         "fouls_1" => 0,
                         "innings_list" => [],
                         "innings_redo_list" => [],
                         "result_3b" => 0,
                         "hs" => 0,
                         "discipline" => if tournament_monitor&.tournament.is_a?(Tournament)
                                           tournament_monitor&.tournament&.discipline&.name
                                         else
                                           nil
                                         end,
                         "gd" => 0.0,
                         "balls_goal" => if tournament_monitor.is_a?(PartyMonitor)
                                           game.data["balls_goal_a"]
                                         else
                                           data["playera"].andand["balls_goal"] ||
                                             tournament_monitor&.tournament&.handicap_tournier? &&
                                               seeding_from("playera").balls_goal.presence ||
                                             tournament_monitor&.balls_goal ||
                                             tournament_monitor&.tournament&.balls_goal ||
                                             tournament_monitor&.tournament&.data.andand[:balls_goal]
                                         end,
                         "tc" => if tournament_monitor.is_a?(PartyMonitor)
                                   game.data["timeouts"]
                                 else
                                   tournament_monitor&.timeouts ||
                                     tournament_monitor&.tournament&.timeouts ||
                                     tournament_monitor&.tournament&.data.andand[:timeouts] ||
                                     0
                                 end
                       },
                       "playerb" => {
                         "result" => 0,
                         "innings" => 0,
                         "fouls_1" => 0,
                         "innings_list" => [],
                         "innings_redo_list" => [],
                         "result_3b" => 0,
                         "hs" => 0,
                         "discipline" => if tournament_monitor&.tournament.is_a?(Tournament)
                                           tournament_monitor&.tournament&.discipline&.name
                                         else
                                           nil
                                         end,
                         "gd" => 0.0,
                         "balls_goal" => if tournament_monitor.is_a?(PartyMonitor)
                                           game.data["balls_goal_a"]
                                         else
                                           data["playerb"].andand["balls_goal"] ||
                                             tournament_monitor&.tournament&.handicap_tournier? &&
                                               seeding_from("playerb").balls_goal.presence ||
                                             tournament_monitor&.balls_goal ||
                                             tournament_monitor&.tournament&.balls_goal ||
                                             tournament_monitor&.tournament&.data.andand[:balls_goal]
                                         end,
                         "tc" => if tournament_monitor.is_a?(PartyMonitor)
                                   game.data["timeouts"]
                                 else
                                   tournament_monitor&.timeouts ||
                                     tournament_monitor&.tournament&.timeouts ||
                                     tournament_monitor&.tournament&.data.andand["timeouts"] ||
                                     0
                                 end
                       },
                       "current_inning" => {
                         "active_player" => current_kickoff_player,
                         "balls" => 0
                       }
                     })
    # self.panel_state = "pointer_mode"
    # self.current_element = "pointer_mode"
    # finish_warmup! #TODO  INTERMEDIATE SOLUTION UNTIL SHOOTOUT WORKS
    data.except!("ba_results", "sets")
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def display_name
    if DEBUG
      Rails.logger.info "------------m6[#{id}]--------->>> display_name <<<------------------------------------------"
    end
    t_no = (name || table.name)&.match(/.*(\d+)/).andand[1]
    I18n.t("table_monitors.display_name", t_no:)
  rescue StandardError => e
    Rails.logger.info "ERROR:m6[#{id}] #{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def seeding_from(role)
    if DEBUG
      Rails.logger.info "-------------m6[#{id}]-------->>> #{"seeding_from(#{role})"} <<<\
------------------------------------------"
    end
    # TODO: - puh can't this be easiere?
    player = game.game_participations.where(role:).first&.player
    if player.present?
      player.seedings.where("seedings.id >= #{Seeding::MIN_ID}")
            .where(tournament_id: tournament_monitor.tournament_id).first
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def balls_left(n_balls_left)
    if DEBUG
      Rails.logger.info "---------------m6[#{id}]------>>> #{"balls_left(#{n_balls_left})"} <<<\
------------------------------------------"
    end
    balls_added = data["balls_on_table"].to_i - n_balls_left
    add_n_balls(balls_added)
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def foul_two
    debug = DEBUG
    if debug
      Rails.logger.info "---------------m6[#{id}]------>>> foul_two <<<\
------------------------------------------"
    end
    if playing?
      Rails.logger.info("foul_two +++++ m6[#{id}]A: playing?") if debug
      current_role = data["current_inning"]["active_player"]
      init_lists(current_role)
      data[current_role]["innings_foul_redo_list"][-1] = data[current_role]["innings_foul_redo_list"][-1] - 2
      innings_sum = data[current_role]["innings_list"]&.sum.to_i
      data[current_role]["result"] =
        innings_sum + data[current_role]["innings_foul_list"].to_a.sum +
          data[current_role]["innings_foul_redo_list"].to_a.sum
      data_will_change!
      self.copy_from = nil
      terminate_current_inning
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def foul_one
    debug = DEBUG
    if debug
      Rails.logger.info "-------------m6[#{id}]-------->>> foul_two <<<\
------------------------------------------"
    end
    if playing?
      Rails.logger.info("foul_one +++++ A: playing?") if debug
      current_role = data["current_inning"]["active_player"]
      init_lists(current_role)
      data[current_role]["innings_foul_redo_list"][-1] = data[current_role]["innings_foul_redo_list"][-1].to_i - 1
      data[current_role]["fouls_1"] = data[current_role]["fouls_1"].to_i + 1
      recompute_result(current_role)
      if data[current_role]["fouls_1"] > 2
        data[current_role]["fouls_1"] = 0
        data[current_role]["innings_foul_redo_list"][-1] = data[current_role]["innings_foul_redo_list"][-1].to_i - 15
        data["extra_balls"] = data["extra_balls"].to_i + (15 - data["balls_on_table"].to_i)
        recompute_result(current_role)
        self.copy_from = nil
        data_will_change!
      else
        data_will_change!
        self.copy_from = nil
        terminate_current_inning
      end
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def displays_clock?
    data["free_game_form"] != "pool"
  end

  def recompute_result(current_role)
    innings_sum = data[current_role]["innings_list"]&.sum.to_i
    other_player = current_role == "playera" ? "playerb" : "playera"
    other_innings_sum = data[other_player]["innings_list"]&.sum.to_i
    total_sum = innings_sum + other_innings_sum +
      data[current_role]["innings_redo_list"][-1].to_i - data["extra_balls"].to_i
    data["balls_on_table"] = 15 - ((total_sum % 14).zero? ? 0 : total_sum % 14)
    data[current_role]["result"] =
      innings_sum + data[current_role]["innings_foul_list"].to_a.sum +
        data[current_role]["innings_foul_redo_list"].to_a.sum
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def init_lists(current_role)
    data[current_role]["innings_list"] ||= []
    data[current_role]["innings_foul_list"] ||= []
    data[current_role]["innings_redo_list"] = [0] if data[current_role]["innings_redo_list"].blank?
    return unless data[current_role]["innings_foul_redo_list"].blank?

    data[current_role]["innings_foul_redo_list"] = [0]
  end

  def add_n_balls(n_balls, player = nil)
    if DEBUG
      Rails.logger.info "-------------m6[#{id}]-------->>> #{"add_n_balls(#{n_balls})"} <<<\
------------------------------------------"
    end
    if discipline == "Biathlon"
      balls_goal_3b = 15
      data["biathlon_phase"] ||= "3b"
    end
    n_balls_left = data["balls_on_table"].to_i - n_balls
    if [1, 0].include?(n_balls_left)
      current_role = data["current_inning"]["active_player"]
      to_play = if data[current_role].andand["balls_goal"].to_i <= 0
                  99_999
                else
                  data[current_role].andand["balls_goal"].to_i -
                    (data[current_role].andand["result"].to_i +
                      data[current_role]["innings_redo_list"][-1].to_i)
                end
      if n_balls <= to_play || data["allow_overflow"].present?
        data["balls_counter_stack"] << data["balls_counter"].to_i
        data["balls_counter"] += 14 + (1 - n_balls_left)
      end
    end
    debug = DEBUG # true
    @msg = nil
    # noinspection RubyResolve
    if playing?
      Rails.logger.info("addn +++++ m6[#{id}]A: playing?") if debug
      if player.present?
        current_role = player.presence
        other_player = current_role == "playera" ? "playerb" : "playera"
        init_lists(other_player)
        if data["current_inning"]["active_player"] != player
          data[other_player]["innings"] += 1
          data[other_player]["innings_list"] << 0
          data[other_player]["innings_foul_list"] << 0
        end
      else
        current_role = data["current_inning"]["active_player"]
      end
      init_lists(current_role)
      to_play = if data[current_role].andand["balls_goal"].to_i <= 0
                  99_999
                else
                  data[current_role].andand["balls_goal"].to_i - (data[current_role].andand["result"].to_i +
                    data[current_role]["innings_redo_list"][-1].to_i)
                end
      if data["biathlon_phase"] == "3b"
        to_play_3b = balls_goal_3b - (data[current_role].andand["result"].to_i +
          data[current_role]["innings_redo_list"][-1].to_i)
      end
      if data["biathlon_phase"] != "3b" || n_balls <= to_play_3b
        if n_balls <= to_play || data["allow_overflow"].present?
          if data["biathlon_phase"] == "3b"
            add_3b = [n_balls, to_play_3b].min
            data[current_role]["innings_redo_list"][-1] =
              [(data[current_role]["innings_redo_list"][-1].to_i + add_3b.to_i), 0].max
            recompute_result(current_role)
            if debug
              Rails.logger.info("addn +++++ m6[#{id}]B: n_balls <= to_play || \
data[\"allow_overflow\"].present?")
            end
            if (data[current_role]["innings_list"]&.sum.to_i +
              data[current_role]["innings_redo_list"][-1].to_i) == balls_goal_3b
              other_player = current_role == "playera" ? "playerb" : "playera"
              data["biathlon_phase"] = "5k"
              Array(data[current_role]["innings_list"]).each_with_index do |val, ix|
                data[current_role]["innings_list"][ix] = val.to_i * 6
              end
              data[current_role]["result"] = data[current_role]["result"].to_i * 6
              data[current_role]["innings_redo_list"][-1] = data[current_role]["innings_redo_list"][-1].to_i * 6
              Array(data[other_player]["innings_list"]).each_with_index do |val, ix|
                data[other_player]["innings_list"][ix] = val.to_i * 6
              end
              data[other_player]["result"] = data[other_player]["result"] * 6
              if data[other_player]["innings_redo_list"].present?
                data[other_player]["innings_redo_list"][-1] =
                  data[other_player]["innings_redo_list"][-1].to_i * 6
              end
              data[current_role]["result_3b"] =
                (data[current_role]["innings_list"]&.sum.to_i + data[current_role]["innings_redo_list"][-1].to_i) / 6
              data[other_player]["result_3b"] =
                (data[other_player]["innings_list"]&.sum.to_i + data[other_player]["innings_redo_list"][-1].to_i) / 6
              data[current_role]["innings_3b"] = data[current_role]["innings"].to_i
              data[other_player]["innings_3b"] = data[other_player]["innings"].to_i
            end
          else
            Rails.logger.info("addn +++++ m6[#{id}]B: n_balls <= to_play || data[\"allow_overflow\"].present?") if debug
            add = [n_balls, to_play].min
            data[current_role]["fouls_1"] = 0
            data[current_role]["innings_redo_list"][-1] =
              [(data[current_role]["innings_redo_list"][-1].to_i + add.to_i), 0].max
            recompute_result(current_role)
          end
          if add == to_play
            Rails.logger.info("addn +++++ m6[#{id}]C: add == to_play") if debug
            data_will_change!
            self.copy_from = nil
            terminate_current_inning(player)
          else
            Rails.logger.info("addn +++++ m6[#{id}]D: add != to_play") if debug
            self.copy_from = nil
            data_will_change!
          end
        end
      else
        @msg = "Game Finished - no more inputs allowed"
        nil
      end
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    Tournament.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def reset_timer!
    if DEBUG
      Rails.logger.info "---------------m6[#{id}]------>>> reset_timer! <<<------------------------------------------"
    end
    assign_attributes(
      active_timer: nil,
      timer_start_at: nil,
      timer_finish_at: nil,
      timer_halt_at: nil
    )
  rescue StandardError => e
    Tournament.logger.info "#{e}, #{e.backtrace.to_a.join("\n")}"
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace.to_a.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def get_options!(locale)
    I18n.with_locale(locale) do
      show_game = game.present? ? game : prev_game
      show_data = game.present? ? data : prev_data
      show_tournament_monitor = game.present? ? tournament_monitor : prev_tournament_monitor
      gps = show_game&.game_participations&.order(:role).to_a
      options = HashWithIndifferentAccess.new(
        showing_prev_game: game.blank?,
        free_game_form: show_data["free_game_form"],
        first_break_choice: show_data["first_break_choice"],
        balls_on_table: show_data["balls_on_table"],
        balls_counter: show_data["balls_counter"],
        extra_balls: show_data["extra_balls"],
        warntime: show_data["warntime"],
        gametime: show_data["gametime"],
        team_size: show_data["team_size"],
        redo_sets: show_data["redo_sets"],
        id:,
        name:,
        game_name: show_game&.display_gname,
        tournament_title: show_tournament_monitor&.tournament&.title,
        current_round: show_tournament_monitor&.current_round,
        timeout: if show_tournament_monitor.is_a?(PartyMonitor)
                   nil
                 else
                   show_tournament_monitor&.timeout || show_data["timeout"].to_i
                 end,
        timeouts: if show_tournament_monitor.is_a?(PartyMonitor)
                    nil
                  else
                    show_tournament_monitor&.timeouts || show_data["timeouts"].to_i
                  end,
        innings_goal: show_data["innings_goal"].presence.to_i,
        active_timer: show_tournament_monitor.is_a?(PartyMonitor) ? nil : active_timer,
        start_at: show_tournament_monitor.is_a?(PartyMonitor) ? nil : timer_start_at,
        finish_at: show_tournament_monitor.is_a?(PartyMonitor) ? nil : timer_finish_at,
        current_sets_a: show_data["ba_results"].andand["Sets1"].to_i,
        current_sets_b: show_data["ba_results"].andand["Sets2"].to_i,
        current_kickoff_player: show_data["current_kickoff_player"].presence || "playera",
        current_left_player: show_data["current_left_player"].presence || "playera",
        current_right_player: if (show_data["current_left_player"].presence || "playera") == "playera"
                                "playerb"
                              else
                                "playera"
                              end,
        current_left_color: show_data["current_left_color"].presence || "white",
        current_right_color: if (show_data["current_left_color"].presence || "white") == "white"
                               "yellow"
                             else
                               "white"
                             end,
        sets_to_play: show_data["sets_to_play"],
        sets_to_win: show_data["sets_to_win"],
        kickoff_switches_with: show_data["kickoff_switches_with"].presence || "set",
        color_remains_with_set: show_data["color_remains_with_set"],
        allow_overflow: show_data["allow_overflow"],
        allow_follow_up: show_data["allow_follow_up"],
        balls_counter_stack: show_data["balls_counter_stack"],
        fixed_display_left: show_data["fixed_display_left"],
        player_a_active: playing? &&
          (show_data["current_inning"].andand["active_player"] == gps[0]&.role),
        player_b_active: playing? &&
          (show_data["current_inning"].andand["active_player"] == gps[1]&.role),
        player_a: {
          logo: (gps[0]&.player&.club&.logo unless gps[0]&.player&.guest?) || gps[0]&.player&.logo,
          lastname: gps[0]&.player&.lastname || "Spieler A",
          shortname: gps[0]&.player&.shortname || "Spieler A",
          firstname_short: if gps[0]&.player&.firstname.present?
                             "#{ gps[0]&.player&.firstname&.gsub(
                               "Dr. ", ""
                             ).andand[0] }. "
                           else
                             ""
                           end,
          firstname: gps[0]&.player&.firstname,
          fullname: if show_tournament_monitor&.id.present? ||
            gps[0]&.player.is_a?(Team)
                      gps[0]&.player&.fullname
                    elsif gps[0]&.player&.guest?
                      gps[0]&.player&.fullname
                    else
                      gps[0]&.player&.simple_firstname.presence || gps[0]&.player&.lastname
                    end,
          balls_goal: show_data[gps[0].andand.role].andand["balls_goal"].presence.to_i,
          fouls_1: show_data[gps[0]&.role].andand["fouls_1"],
          discipline: show_data[gps[0]&.role].andand["discipline"] ||
            show_tournament_monitor&.tournament.is_a?(Tournament) &&
              show_tournament_monitor&.tournament&.discipline&.name,
          result: show_data[gps[0]&.role].andand["result"].to_i,
          hs: show_data[gps[0]&.role].andand["hs"].to_i,
          gd: show_data[gps[0]&.role].andand["gd"],
          innings: show_data[gps[0]&.role].andand["innings"].to_i,
          tc: show_data[gps[0]&.role].andand["tc"].to_i
        },
        player_b: {
          logo: (gps[1]&.player&.club&.logo unless gps[1]&.player&.guest?) || gps[1]&.player&.logo,
          lastname: gps[1]&.player&.lastname || "Spieler B",
          shortname: gps[1]&.player&.shortname || "Spieler B",
          firstname_short: if gps[1]&.player&.firstname.present?
                             "#{gps[1]&.player&.firstname&.gsub(
                               "Dr. ", ""
                             ).andand[0]}. "
                           else
                             ""
                           end,
          firstname: gps[1]&.player&.firstname,
          fullname: if show_tournament_monitor&.id.present? ||
            gps[1]&.player.is_a?(Team)
                      gps[1]&.player&.fullname
                    elsif gps[1]&.player&.guest?
                      gps[1]&.player&.fullname
                    else
                      gps[1]&.player&.simple_firstname.presence || gps[1]&.player&.lastname
                    end,
          balls_goal: show_data[gps[1]&.role].andand["balls_goal"].presence.to_i,
          fouls_1: show_data[gps[1]&.role].andand["fouls_1"],
          discipline: show_data[gps[1]&.role].andand["discipline"] ||
            show_tournament_monitor&.tournament.is_a?(Tournament) &&
              show_tournament_monitor&.tournament&.discipline&.name,
          result: show_data[gps[1]&.role].andand["result"].to_i,
          hs: show_data[gps[1]&.role].andand["hs"].to_i,
          gd: show_data[gps[1]&.role].andand["gd"],
          innings: show_data[gps[1]&.role].andand["innings"].to_i,
          tc: show_data[gps[1]&.role].andand["tc"].to_i
        },
        current_inning: {
          balls: show_data["current_inning"].andand["balls"].to_i,
          active_player: show_data["current_inning"].andand["active_player"]
        }
      ).stringify_keys
      self.options = options
      self.gps = gps
      self.location = table.location
      self.tournament = if tournament_monitor.is_a?(PartyMonitor)
                          tournament_monitor&.party
                        else
                          tournament_monitor&.tournament
                        end
      self.my_table = table
    end
  end

  attr_reader :msg

  def marshal_dup(hash)
    Marshal.load(Marshal.dump(hash))
  end
  def evaluate_panel_and_current
    return unless remote_control_detected

    if DEBUG
      Rails.logger.info "--------------m6[#{id}]------->>> evaluate_panel_and_current <<<\
------------------------------------------"
    end
    element_to_panel_state = {
      "undo" => "inputs",
      "minus_1" => "inputs",
      "minus_2" => "inputs",
      "minus_10" => "inputs",
      "minus_5" => "inputs",
      "minus_4" => "inputs",
      "next_step" => "inputs",
      "add_10" => "inputs",
      "add_5" => "inputs",
      "add_4" => "inputs",
      "add_2" => "inputs",
      "add_1" => "inputs",
      "numbers" => "inputs",
      "pause" => "timer",
      "play" => "timer",
      "stop" => "timer",
      "pointer_mode" => "pointer_mode",
      "number_field" => "numbers",
      "nnn_1" => "numbers",
      "nnn_2" => "numbers",
      "nnn_3" => "numbers",
      "nnn_4" => "numbers",
      "nnn_5" => "numbers",
      "nnn_6" => "numbers",
      "nnn_7" => "numbers",
      "nnn_8" => "numbers",
      "nnn_9" => "numbers",
      "nnn_0" => "numbers",
      "nnn_del" => "numbers",
      "nnn_enter" => "numbers",
      "nnn_esc" => "numbers",
      "start_game" => "shootout",
      "change" => "shootout",
      "continue" => "setup",
      "practice_a" => "setup",
      "practice_b" => "setup"
    }
    new_panel_state = nil
    # noinspection RubyResolve
    if warmup_modal_should_be_open?
      new_panel_state = "setup"
    elsif shootout_modal_should_be_open?
      new_panel_state = "shootout"
    elsif numbers_modal_should_be_open?
      new_panel_state = "numbers"
    elsif set_over? || final_set_score?
      new_panel_state = "show_results"
    end
    if new_panel_state.present?
      new_current_element = TableMonitor::DEFAULT_ENTRY[new_panel_state]
      if new_panel_state == "timer"
        new_current_element = timer_finish_at.present? && timer_halt_at.blank? ? "pause" : "play"
      end
    else
      new_panel_state = panel_state
      new_current_element = current_element
    end
    assign_attributes(panel_state: new_panel_state,
                      current_element: if element_to_panel_state[new_current_element] == new_panel_state
                                         new_current_element
                                       else
                                         TableMonitor::DEFAULT_ENTRY[panel_state]
                                       end)
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def more_sets?
    data["sets_to_play"].to_i > 1 && (data["sets_to_win"].to_i > 1)
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def set_n_balls(n_balls, change_to_pointer_mode = false)
    if DEBUG
      Rails.logger.info "-------------m6[#{id}]--------\
>>> #{"set_n_balls(#{n_balls}, #{change_to_pointer_mode})"} <<<\
------------------------------------------"
    end
    if discipline == "Biathlon"
      balls_goal_3b = 15
      data["biathlon_phase"] ||= "3b"
    end
    debug = true # true
    Rails.logger.info("setn ++++m6[#{id}]+  : ") if debug
    @msg = nil
    if playing?
      Rails.logger.info("setn +++++ m6[#{id}]A: playing?") if debug
      current_role = data["current_inning"]["active_player"]
      init_lists(current_role)
      to_play = data[current_role].andand["balls_goal"].to_i <= 0 ? 99_999 : data[current_role].andand["balls_goal"].to_i - data[current_role].andand["result"].to_i
      if n_balls <= to_play || data["allow_overflow"].present?
        Rails.logger.info("setn +++++ m6[#{id}]B: n_balls <= to_play || data[\"allow_overflow\"].present?") if debug
        set = [n_balls, to_play].min
        data[current_role]["innings_redo_list"][-1] = set
        to_play_3b = balls_goal_3b - data[current_role].andand["result"].to_i if data["biathlon_phase"] == "3b"
        if data["biathlon_phase"] != "3b" || n_balls <= to_play_3b
          if set == to_play
            Rails.logger.info("setn +++++ m6[#{id}]C: add == to_play") if debug
            data_will_change!
            assign_attributes(nnn: nil, panel_state: change_to_pointer_mode ? "pointer_mode" : panel_state)
            save
            terminate_current_inning
          else
            Rails.logger.info("setn +++++ m6[#{id}]D: add != to_play") if debug
            # data[current_role]["innings_redo_list"].pop if Array(data[current_role]["innings_redo_list"]).last.to_i > 10000
            data_will_change!
            assign_attributes(nnn: nil, panel_state: change_to_pointer_mode ? "pointer_mode" : panel_state)
            save
          end

          to_play_3b = balls_goal_3b - data[current_role].andand["result"].to_i if data["biathlon_phase"] == "3b"
          if data["biathlon_phase"] != "3b" || n_balls <= to_play_3b
            if n_balls <= to_play || data["allow_overflow"].present?
              if data["biathlon_phase"] == "3b"
                [n_balls, to_play_3b].min
                # data[current_role]['innings_redo_list'][-1] = set
                recompute_result(current_role)
                if debug
                  Rails.logger.info("addn +++++ m6[#{id}]B: n_balls <= to_play || data[\"allow_overflow\"].present?")
                end
                if (data[current_role]["innings_list"]&.sum.to_i + data[current_role]["innings_redo_list"][-1].to_i) == balls_goal_3b
                  other_player = current_role == "playera" ? "playerb" : "playera"
                  data["biathlon_phase"] = "5k"
                  Array(data[current_role]["innings_list"]).each_with_index do |val, ix|
                    data[current_role]["innings_list"][ix] = val.to_i * 6
                  end
                  data[current_role]["result"] = data[current_role]["result"].to_i * 6
                  data[current_role]["innings_redo_list"][-1] = data[current_role]["innings_redo_list"][-1].to_i * 6
                  Array(data[other_player]["innings_list"]).each_with_index do |val, ix|
                    data[other_player]["innings_list"][ix] = val.to_i * 6
                  end
                  data[other_player]["result"] = data[other_player]["result"].to_i * 6
                  data[other_player]["innings_redo_list"][-1] = data[other_player]["innings_redo_list"][-1].to_i * 6
                  data[current_role]["result_3b"] =
                    (data[current_role]["innings_list"]&.sum.to_i + data[current_role]["innings_redo_list"][-1].to_i) / 6
                  data[other_player]["result_3b"] =
                    (data[other_player]["innings_list"]&.sum.to_i + data[other_player]["innings_redo_list"][-1].to_i) / 6
                  data[current_role]["innings_3b"] = data[current_role]["innings"].to_i
                  data[other_player]["innings_3b"] = data[other_player]["innings"].to_i
                end
              else
                if debug
                  Rails.logger.info("addn +++++ m6[#{id}]B: n_balls <= to_play || data[\"allow_overflow\"].present?")
                end
                add = [n_balls, to_play].min
                data[current_role]["fouls_1"] = 0
                data[current_role]["innings_redo_list"][-1] =
                  [add, 0].max
                recompute_result(current_role)
              end
              if add == to_play
                Rails.logger.info("addn +++++ m6[#{id}]C: add == to_play") if debug
                data_will_change!
                self.copy_from = nil
                terminate_current_inning(player)
              else
                Rails.logger.info("addn +++++ m6[#{id}]D: add != to_play") if debug
                self.copy_from = nil
                data_will_change!
              end
            end
          else
            @msg = "Game Finished - no more inputs allowed"
            nil
          end
        end
      end
    else
      @msg = "Game Finished - no more inputs allowed"
      nil
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def terminate_current_inning(player = nil)
    if DEBUG
      Rails.logger.info "--------------m6[#{id}]------->>> terminate_current_inning <<<------------------------------------------"
    end
    @msg = nil
    TableMonitor.transaction do
      current_role = player.presence || data["current_inning"]["active_player"]
      if playing? && (data["innings_goal"].to_i.zero? || data[current_role]["innings"].to_i < data["innings_goal"].to_i)
        if data[current_role]["fouls_1"].to_i > 2
          data[current_role]["fouls_1"] = 0
          data[current_role]["innings_foul_redo_list"][-1] = data[current_role]["innings_foul_redo_list"][-1].to_i - 15
        end
        n_balls = Array(data[current_role]["innings_redo_list"]).pop.to_i
        n_fouls = Array(data[current_role]["innings_foul_redo_list"]).pop.to_i
        data["balls_counter_stack"] << data["balls_counter"].to_i if n_balls != 0
        data["balls_counter"] -= n_balls
        init_lists(current_role)
        data[current_role]["innings_list"] << n_balls
        data[current_role]["innings_foul_list"] << n_fouls
        recompute_result(current_role)
        if data["innings_goal"].to_i.zero? || data[current_role]["innings"].to_i < data["innings_goal"].to_i
          data[current_role]["innings"] += 1
        end
        data[current_role]["hs"] = n_balls if n_balls > data[current_role]["hs"].to_i
        data[current_role]["gd"] =
          format("%.2f", data[current_role]["result"].to_f / data[current_role].andand["innings"].to_i)
        if discipline == "Biathlon" && current_role == "playerb"
          innings_goal_3b = 30
          if data["biathlon_phase"] == "3b" && discipline == "Biathlon" && data[current_role]["innings"] == innings_goal_3b
            data["biathlon_phase"] = "5k"
            other_player = current_role == "playera" ? "playerb" : "playera"
            Array(data[current_role]["innings_list"]).each_with_index do |val, ix|
              data[current_role]["innings_list"][ix] = val * 6
            end
            data[current_role]["result"] = data[current_role]["result"] * 6
            data[current_role]["innings_redo_list"][-1] = data[current_role]["innings_redo_list"][-1] * 6
            Array(data[other_player]["innings_list"]).each_with_index do |val, ix|
              data[other_player]["innings_list"][ix] = val * 6
            end
            data[other_player]["result"] = data[other_player]["result"] * 6
            if data[other_player]["innings_redo_list"].present?
              data[other_player]["innings_redo_list"][-1] =
                data[other_player]["innings_redo_list"][-1] * 6
            end
            data[current_role]["result_3b"] =
              (data[current_role]["innings_list"]&.sum.to_i + data[current_role]["innings_redo_list"][-1].to_i) / 6
            data[other_player]["result_3b"] =
              (data[other_player]["innings_list"]&.sum.to_i + data[other_player]["innings_redo_list"][-1].to_i) / 6
            data[current_role]["innings_3b"] = data[current_role]["innings"].to_i
            data[other_player]["innings_3b"] = data[other_player]["innings"].to_i

          end
        end
        other_player = current_role == "playera" ? "playerb" : "playera"
        data["current_inning"]["active_player"] = other_player
        if data[current_role]["innings_redo_list"]&.blank?
          data[other_player]["innings_redo_list"] =
            [0]
        end
        data_will_change!
        save!
        evaluate_result
      else
        @msg = "Game Finished - no more inputs allowed"
        nil
      end
    end
  rescue StandardError => e
    Tournament.logger.info "#{e}, #{e.backtrace&.join("\n")}"
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def player_controlled?
    tournament_monitor.blank? || tournament_monitor.tournament.blank? || tournament_monitor.tournament.player_controlled?
  end

  def follow_up?
    left_player_id = data["fixed_display_left"].blank? ? data["current_kickoff_player"] : data["current_left_player"]
    right_player_id = left_player_id == "playera" ? "playerb" : "playera"
    active_player_is_follow_up_player = (data["current_inning"].andand["active_player"] == right_player_id)
    kickoff_player_has_balls_goal = data[left_player_id].andand["balls_goal"].presence.to_i.positive?
    has_reached_balls_goal = data[left_player_id].andand["balls_goal"].presence.to_i.positive? && (data[left_player_id].andand["result"].to_i >= data[left_player_id].andand["balls_goal"].to_i)
    innings_goal_exists = data["innings_goal"].presence.to_i.positive?
    kickoff_player_has_reached_innings_goal = data["innings_goal"].presence.to_i.positive? && data[left_player_id].andand["innings"].to_i >= data["innings_goal"].to_i
    ret = data.present? &&
      (active_player_is_follow_up_player &&
        (kickoff_player_has_balls_goal && has_reached_balls_goal ||
          (innings_goal_exists && kickoff_player_has_reached_innings_goal))
      )
    if DEBUG
      Rails.logger.info("+++++ FOLLOW_UP? returns #{ret}: (active_player_is_follow_up_player:#{active_player_is_follow_up_player} && (kickoff_player_has_balls_goal:#{kickoff_player_has_balls_goal} && has_reached_balls_goal:#{has_reached_balls_goal} || (innings_goal_exists:#{innings_goal_exists} && kickoff_player_has_reached_innings_goal:#{kickoff_player_has_reached_innings_goal}))")
    end
    ret
  rescue StandardError => e
    Rails.logger.info "--------------m6[#{id}]------->>> numbers <<<------------------------------------------" if DEBUG
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def redo
    Rails.logger.info "----------------m6[#{id}]----->>> redo <<<------------------------------------------" if DEBUG
    return unless playing?

    current_role = data["current_inning"]["active_player"]
    return unless data[current_role]["discipline"] == "14.1 endlos"
    return unless copy_from.present?

    self.copy_from += 1
    deep_merge_data!(versions[self.copy_from -= 1].reify.data)
    data_will_change!
    save!
  end

  def undo
    Rails.logger.info "-----------------m6[#{id}]---->>> undo <<<------------------------------------------" if DEBUG
    if playing? || set_over?
      current_role = data["current_inning"]["active_player"]
      the_other_player = (current_role == "playera" ? "playerb" : "playera")
      if data[current_role]["discipline"] == "14.1 endlos"
        if (data["playera"]["innings"].to_i + data["playerb"]["innings"].to_i +
          data["playera"]["result"].to_i + data["playerb"]["result"].to_i +
          data["sets"].to_a.length +
          data["playera"]["innings_redo_list"].andand[-1].to_i + data["playerb"]["innings_redo_list"].andand[-1].to_i).zero?
          self.state = "match_shootout"
        elsif self.copy_from.present?
          copy_from_ = self.copy_from - 1
          # w = versions[self.copy_from].reify(dup: true)
          # w.attributes
          # save!
          prev_version = versions[copy_from_].reify
          prev_version.copy_from = copy_from_
          prev_version.save!
          reload
          # deep_merge_data!(versions[self.copy_from].reify.data)
        else
          if set_over?
            play_versions = versions.where("whodunnit ilike '%in `do_play''%'").to_a
            ix = play_versions.reverse.find_index { |v| v.reify.state == "playing" }
            p_version = PaperTrail::Version[play_versions.reverse[ix].id + 1]
            copy_from_ = p_version.index
            prev_version = p_version.reify
          else
            copy_from_ = versions.last.index
            prev_version = versions.last.reify
          end
          prev_version.copy_from = copy_from_
          prev_version.save!
          reload
          # deep_merge_data!(versions.last.reify.data)
        end
      elsif set_over?
        version = self.versions[-3]
        tt = version.reify
        tt.copy_from = version.index
        tt.save!
        reload
      elsif simple_set_game? && data["sets"].present?
        play_versions = if self.copy_from.present?
                          versions.where("whodunnit ilike '%in `switch_to_next_set''%'").select do |v|
                            v.index < self.copy_from
                          end
                        else
                          versions.where("whodunnit ilike '%in `switch_to_next_set''%'")
                        end
        p_version = PaperTrail::Version[
          play_versions[-2].id + 1
        ]
        copy_from_ = p_version.index
        prev_version = p_version.reify
        prev_version.copy_from = copy_from_
        prev_version.save!
        reload
      elsif (data[the_other_player]["innings"]).to_i.positive?
        if data[the_other_player]["innings_list"].present?
          arr = Array(data[the_other_player]["innings_list"])
          data[the_other_player]["innings_redo_list"] << arr.pop.to_i if arr.present?
        end
        data[the_other_player]["innings"] -= 1
        data[the_other_player]["result"] = data[the_other_player]["innings_list"]&.sum.to_i
        data[the_other_player]["hs"] = data[the_other_player]["innings_list"]&.max.to_i
        data[the_other_player]["gd"] =
          format("%.2f", data[the_other_player]["result"].to_f / data[current_role]["innings"].to_i)
        data["current_inning"]["active_player"] = the_other_player
      elsif (data["playera"]["innings"].to_i + data["playerb"]["innings"].to_i +
        data["playera"]["result"].to_i + data["playerb"]["result"].to_i +
        data["sets"].to_a.length +
        data["playera"]["innings_redo_list"].andand[-1].to_i + data["playerb"]["innings_redo_list"].andand[-1].to_i).zero?
        self.state = "match_shootout"
      end
      data_will_change!
      save!
    else
      @msg = "Game Finished - no more inputs allowed"
      nil
    end
  rescue StandardError => e
    Tournament.logger.info "#{e}, #{e.backtrace&.join("\n")}"
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def save_result
    game_set_result = {}
    if game.present?
      game_set_result = {
        "Gruppe" => game.group_no,
        "Partie" => game.seqno,

        "Spieler1" => game.game_participations.where(role: "playera").first&.player&.ba_id,
        "Spieler2" => game.game_participations.where(role: "playerb").first&.player&.ba_id,
        "Innings1" => data["playera"]["innings_list"].dup,
        "Innings2" => data["playerb"]["innings_list"].dup,
        "Ergebnis1" => data["playera"]["result"].to_i,
        "Ergebnis2" => data["playerb"]["result"].to_i,
        "Aufnahmen1" => data["playera"]["innings"].to_i,
        "Aufnahmen2" => data["playerb"]["innings"].to_i,
        "3BErgebnis1" => data["playera"]["result_3b"].to_i,
        "3BErgebnis2" => data["playerb"]["result_3b"].to_i,
        "3BAufnahmen1" => data["playera"]["innings_3b"].to_i,
        "3BAufnahmen2" => data["playerb"]["innings_3b"].to_i,
        "Höchstserie1" => data["playera"]["hs"].to_i,
        "Höchstserie2" => data["playerb"]["hs"].to_i,
        "Tischnummer" => game.table_no
      }
      ba_results = data["ba_results"] ||
        {
          "Gruppe" => game.group_no,
          "Partie" => game.seqno,

          "Spieler1" => game.game_participations.where(role: "playera").first&.player&.ba_id,
          "Spieler2" => game.game_participations.where(role: "playerb").first&.player&.ba_id,
          "Sets1" => 0,
          "Sets2" => 0,
          "Ergebnis1" => 0,
          "Ergebnis2" => 0,
          "Aufnahmen1" => 0,
          "Aufnahmen2" => 0,
          "Höchstserie1" => 0,
          "Höchstserie2" => 0,
          "Tischnummer" => game.table_no
        }
      if game_set_result["Ergebnis1"].to_i > game_set_result["Ergebnis2"].to_i
        ba_results["Sets1"] =
          ba_results["Sets1"].to_i + 1
      end
      if game_set_result["Ergebnis1"].to_i < game_set_result["Ergebnis2"].to_i
        ba_results["Sets2"] =
          ba_results["Sets2"].to_i + 1
      end
      ba_results["Ergebnis1"] = ba_results["Ergebnis1"].to_i + game_set_result["Ergebnis1"]
      ba_results["Ergebnis2"] = ba_results["Ergebnis2"].to_i + game_set_result["Ergebnis2"]
      ba_results["Aufnahmen1"] = ba_results["Aufnahmen1"].to_i + game_set_result["Aufnahmen1"]
      ba_results["Aufnahmen2"] = ba_results["Aufnahmen2"].to_i + game_set_result["Aufnahmen2"]
      ba_results["Höchstserie1"] = [ba_results["Höchstserie1"].to_i, game_set_result["Höchstserie1"].to_i].max
      ba_results["Höchstserie2"] = [ba_results["Höchstserie2"].to_i, game_set_result["Höchstserie2"].to_i].max
      deep_merge_data!("ba_results" => ba_results)
    end
    game_set_result
  end

  def save_current_set
    if DEBUG
      Rails.logger.info "----------------m6[#{id}]----->>> save_current_set <<<------------------------------------------"
    end
    if game.present?
      game_set_result = save_result
      sets = Array(data["sets"]).push(game_set_result)
      deep_merge_data!("redo_sets" => [])
      deep_merge_data!("sets" => sets)
      save!
    else
      Rails.logger.info "[prepare_final_game_result] m6[#{id}]ignored - no game"
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def get_max_number_of_wins
    if DEBUG
      Rails.logger.info "---------------m6[#{id}]------>>> get_max_number_of_wins <<<------------------------------------------"
    end
    [data["ba_results"].andand["Sets1"].to_i, data["ba_results"].andand["Sets2"].to_i].max
  rescue StandardError => e
    Rails.logger.info "ERROR:m6[#{id}] #{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def sets_played
    data["ba_results"].andand["Sets1"].to_i + data["ba_results"].andand["Sets2"].to_i
  end

  def switch_to_next_set
    if DEBUG
      Rails.logger.info "---------------m6[#{id}]------>>> switch_to_next_set <<<------------------------------------------"
    end
    kickoff_switches_with = data["kickoff_switches_with"].presence || "set"
    current_kickoff_player = data["current_kickoff_player"]
    case kickoff_switches_with
    when "set"
      current_kickoff_player = current_kickoff_player == "playera" ? "playerb" : "playera"
    when "winner"
      current_kickoff_player = data["sets"][-1]["Innings1"][-1].to_i > data["sets"][-1]["Innings2"][-1].to_i ? "playera" : "playerb"
    end
    options = {
      "Gruppe" => game.group_no,
      "Partie" => game.seqno,

      "Spieler1" => game.game_participations.where(role: "playera").first&.player&.ba_id,
      "Spieler2" => game.game_participations.where(role: "playerb").first&.player&.ba_id,
      "Ergebnis1" => 0,
      "Ergebnis2" => 0,
      "Aufnahmen1" => 0,
      "Aufnahmen2" => 0,
      "Höchstserie1" => 0,
      "Höchstserie2" => 0,
      "Tischnummer" => game.table_no,
      "current_kickoff_player" => current_kickoff_player,
      "playera" =>
        { "result" => 0,
          "innings" => 0,
          "innings_list" => [],
          "innings_redo_list" => [],
          "hs" => 0,
          "gd" => "0.00" },
      "playerb" =>
        { "result" => 0,
          "innings" => 0,
          "innings_list" => [],
          "innings_redo_list" => [],
          "hs" => 0,
          "gd" => "0.00" },
      "current_inning" => {
        "active_player" => current_kickoff_player,
        "balls" => 0
      }
    }

    deep_merge_data!(options)
    assign_attributes(state: "playing")
    save!
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def evaluate_result
    debug = true # true
    if (playing? || set_over? || final_set_score? || final_match_score?) && end_of_set?
      end_of_set! if playing? && simple_set_game? && may_end_of_set?
      if playing?
        end_of_set! if may_end_of_set?
        save_result
        save!
        return
      elsif set_over?
        if data["sets_to_win"].to_i > 1 # TODO: sets to play not implemented correctly
          save_current_set
          max_number_of_wins = get_max_number_of_wins
          if automatic_next_set && data["sets_to_win"].to_i > 1 && max_number_of_wins < data["sets_to_win"].to_i # && (data["sets_to_play"].to_i > Array(data["sets"]).count)
            switch_to_next_set
          else
            acknowledge_result!
          end
          return
        elsif data["sets_to_play"].to_i > 1
          if automatic_next_set && sets_played < data["sets_to_play"].to_i
            switch_to_next_set
          else
            acknowledge_result!
          end
          return
        else
          acknowledge_result! if may_acknowledge_result?
          if final_set_score?
            tournament_monitor&.report_result(self)
            finish_match! if may_finish_match?
          end
        end
      elsif final_set_score?
        tournament_monitor&.report_result(self)
        finish_match! if may_finish_match?
      elsif tournament_monitor.blank? && game.present?
        revert_players
        update(state: "playing")
        do_play
        return
      end
      save! if changes.present?
      reload
      prepare_final_game_result
      tournament_monitor&.report_result(self)
    elsif debug
      Rails.logger.info("eval ***** K:  ! (playing? || set_over? || final_set_score? || final_match_score?) && end_of_set?")
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def start_game(options_ = {})
    options = HashWithIndifferentAccess.new(options_)
    if DEBUG
      Rails.logger.info "-------------m6[#{id}]-------->>> #{"start_game(#{options.inspect})"} <<<------------------------------------------"
    end
    # Unlink any existing game from this table monitor (preserve game history)
    if game.present?
      game.update(table_monitor: nil)
      Rails.logger.info "Unlinked existing game #{game.id} from table monitor #{id}" if DEBUG
    end
    
    # Create a new game for this table monitor
    @game = Game.new(table_monitor: self)
    reload
    @game.update(data: {})
    players = Player.where(id: options["player_a_id"]).order(:dbu_nr).to_a
    team = Player.team_from_players(players)
    GameParticipation.create!(
      game_id: @game.id, player: team, role: "playera"
    )
    @game.save
    players = Player.where(id: options["player_b_id"]).order(:dbu_nr).to_a
    team = Player.team_from_players(players)
    GameParticipation.create!(
      game_id: @game.id, player: team, role: "playerb"
    )
    @game.save
    kickoff_switches_with = options["kickoff_switches_with"].presence || "set"
    color_remains_with_set = options["color_remains_with_set"]
    fixed_display_left = options["fixed_display_left"]
    result = {
      "free_game_form" => options["free_game_form"],
      "first_break_choice" => options["first_break_choice"],
      "extra_balls" => 0,
      "balls_on_table" => (options["balls_on_table"].presence || 15).to_i,
      "warntime" => options["warntime"].to_i,
      "gametime" => options["gametime"].to_i,
      "timeouts" => options["timeouts"].to_i,
      "timeout" => options["timeout"].to_i,
      "sets_to_play" => options["sets_to_play"].to_i,
      "sets_to_win" => options["sets_to_win"].to_i,
      "kickoff_switches_with" => kickoff_switches_with,
      "allow_follow_up" => options["allow_follow_up"],
      "color_remains_with_set" => color_remains_with_set,
      "allow_overflow" => options["allow_overflow"],
      "fixed_display_left" => fixed_display_left,
      "current_kickoff_player" => "playera",
      "current_left_player" => fixed_display_left.present? ? fixed_display_left : "playera",
      "current_left_color" => fixed_display_left == "playerb" ? "yellow" : "white",
      "innings_goal" => options["innings_goal"],
      "playera" => {
        "balls_goal" => if options["free_game_form"] == "pool"
                          options["discipline_a"] == "14.1 endlos" ? options["balls_goal_a"] : 1
                        else
                          options["balls_goal_a"]
                        end,
        "tc" => options["timeouts"].to_i,
        "discipline" => options["discipline_a"],
        "result" => 0,
        "fouls_1" => 0,
        "innings" => 0,
        "innings_list" => [],
        "innings_foul_list" => [],
        "innings_redo_list" => [],
        "innings_foul_redo_list" => [],
        "hs" => 0,
        "gd" => "0.00"
      },
      "playerb" => {
        "balls_goal" => if options["free_game_form"] == "pool"
                          options["discipline_b"] == "14.1 endlos" ? options["balls_goal_b"] : 1
                        else
                          options["balls_goal_b"]
                        end,
        "tc" => options["timeouts"].to_i,
        "discipline" => options["discipline_b"],
        "result" => 0,
        "fouls_1" => 0,
        "innings" => 0,
        "innings_list" => [],
        "innings_foul_list" => [],
        "innings_redo_list" => [],
        "innings_foul_redo_list" => [],
        "hs" => 0,
        "gd" => "0.00"
      }
    }
    result["sets_to_win"] = 8 if /shootout/i.match?(options["discipline_a"])
    initialize_game
    deep_merge_data!(result)
    self.copy_from = nil
    save!
    finish_warmup! if options["discipline_a"] =~ /shootout/i && may_finish_warmup?
    true
  rescue StandardError => e
    msg = "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    Rails.logger.info msg if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def revert_players
    if DEBUG
      Rails.logger.info "--------------m6[#{id}]------->>> revert_players <<<------------------------------------------"
    end
    fixed_display_left = data["fixed_display_left"]
    options = {
      "player_a_id" => game.game_participations.where(role: "playerb").first&.player&.id,
      "player_b_id" => game.game_participations.where(role: "playera").first&.player&.id,
      "timeouts" => data["timeouts"].to_i,
      "timeout" => data["timeout"].to_i,
      "innings_goal" => data["innings_goal"].to_i,
      "balls_goal_a" => data["playerb"]["balls_goal"].to_i,
      "balls_goal_b" => data["playera"]["balls_goal"].to_i,
      "discipline_a" => data["playerb"]["discipline"],
      "discipline_b" => data["playera"]["discipline"],
      "sets_to_play" => data["sets_to_play"].to_i,
      "sets_to_win" => data["sets_to_win"].to_i,
      "kickoff_switches_with" => data["kickoff_switches_with"],
      "allow_follow_up" => data["allow_follow_up"],
      "color_remains_with_set" => data["color_remains_with_set"],
      "allow_overflow" => data["allow_overflow"],
      "fixed_display_left" => data["fixed_display_left"],
      "current_kickoff_player" => "playera",
      "free_game_form" => data["free_game_form"],
      "first_break_choice" => data["first_break_choice"],
      "warntime" => data["warntime"].to_i,
      "gametime" => data["gametime"].to_i,

      "current_left_player" => fixed_display_left.present? ? fixed_display_left : "playera",
      "current_left_color" => fixed_display_left == "playerb" ? "yellow" : "white"
    }
    update(game_id: nil)
    start_game(options)
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def set_player_sequence(players)
    if DEBUG
      Rails.logger.info "--------------m6[#{id}]------->>> #{"set_player_sequence#{players.inspect}"} <<<------------------------------------------"
    end
    (a..d).each_with_index do |ab_seqno, ix|
      next if ix >= players.count

      data["player_map"]["player#{ab_seqno}"] = players[ix]
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def end_of_set?
    if data["playera"]["balls_goal"].to_i.positive? && ((data["playera"]["result"].to_i >= data["playera"]["balls_goal"].to_i ||
      data["playerb"]["result"].to_i >= data["playerb"]["balls_goal"].to_i) &&
      (data["playera"]["innings"] == data["playerb"]["innings"] || !data["allow_follow_up"]))
      return true
    elsif data["innings_goal"].to_i.positive? && data["playera"]["innings"].to_i >= data["innings_goal"].to_i &&
      (data["playera"]["innings"] == data["playerb"]["innings"] || !data["allow_follow_up"])
      return true
    end

    false
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def name
    table&.name
  end

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    data_will_change!
    self.data = JSON.parse(h.to_json)
    # save!
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def deep_delete!(key, do_save = true)
    if DEBUG
      Rails.logger.info "--------------m6[#{id}]------->>> #{"deep_delete!(#{key}, #{do_save})"} <<<\
------------------------------------------"
    end
    h = data.dup
    res = nil
    if h[key].present?
      res = h.delete(key)
      data_will_change!
      self.data = JSON.parse(h.to_json)

      save! if do_save
    end
    res
  rescue StandardError => e
    Rails.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError unless Rails.env == "production"
  end

  def prepare_final_game_result
    if DEBUG
      Rails.logger.info "--------------m6[#{id}]------->>> prepare_final_game_result <<<------------------------------------------"
    end
    if game.present?
      game_ba_result = {
        "Gruppe" => game.group_no,
        "Partie" => game.seqno,

        "Spieler1" => game.game_participations.where(role: "playera").first&.player&.ba_id,
        "Spieler2" => game.game_participations.where(role: "playerb").first&.player&.ba_id,
        "Ergebnis1" => data["playera"]["result"].to_i,
        "Ergebnis2" => data["playerb"]["result"].to_i,
        "Aufnahmen1" => data["playera"]["innings"].to_i,
        "Aufnahmen2" => data["playerb"]["innings"].to_i,
        "Höchstserie1" => data["playera"]["hs"].to_i,
        "Höchstserie2" => data["playerb"]["hs"].to_i,
        "Tischnummer" => game.table_no
      }
      deep_merge_data!("ba_results" => game_ba_result)
      save!
      if tournament_monitor&.id.blank? && final_set_score? && game.present?
        game.deep_merge_data!(data)
        game.save!
      end
    else
      Rails.logger.info "[prepare_final_game_result] m6[#{id}]ignored - no game"
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end

  def simple_set_game?
    data["free_game_form"] == "pool" && data["playera"]["discipline"] != "14.1 endlos"
  end

  def admin_ack_result
    return unless may_acknowledge_result?

    acknowledge_result!
    max_number_of_wins = get_max_number_of_wins
    if data["sets_to_win"].to_i > 1 && max_number_of_wins < data["sets_to_win"].to_i
      switch_to_next_set
    else
      tournament_monitor&.report_result(self)
      finish_match! if may_finish_match?
    end
    save
  end

  def force_next_state
    if %i[warmup warmup_a warmup_b].include?(state.to_sym)
      Rails.logger.info("nxst +++++ B: %i[warmup warmup_a warmup_b].include?(state.to_sym)") if DEBUG
      reset_timer!
      # noinspection RubyResolve
      finish_warmup!
    elsif [:match_shootout].include?(state.to_sym)
      Rails.logger.info("nxst +++++ C: [:match_shootout].include?(state.to_sym)") if DEBUG
      reset_timer!
      finish_shootout!
    elsif set_over? || final_match_score?
      Rails.logger.info("nxst +++++ D: set_over? || final_match_score?") if DEBUG
      evaluate_result
      # acknowledge_result!
      # prepare_final_game_result
    elsif final_set_score?
      Rails.logger.info("nxst +++++ E: final_set_score?") if DEBUG
      if tournament_monitor.present?
        Rails.logger.info("nxst +++++ F: tournament_monitor.present?") if DEBUG
        evaluate_result
        # tournament_monitor.report_result(@table_monitor)
      else
        Rails.logger.info("nxst +++++ G: ! tournament_monitor.present?") if DEBUG
        if tournament_monitor.blank?
          evaluate_result
        else
          # noinspection RubyResolve
          # Tournament.logger.info "[table_monitor_reflex#force_next_state] #{caller[0..4].select{|s| s.include?("/app/").join("\n")}"
          tournament_monitor&.report_result(self)
          finish_match! if may_finish_match?
          reset_table_monitor
        end

      end
    end
  end

  def playing_round?
    %w[playing warmup warmup_a warmup_b match_shootout set_over final_set_score final_match_score].include?(state)
  end

  def reset_table_monitor
    if DEBUG
      Rails.logger.info "--------------m6[#{id}]------->>> reset_table_monitor <<<------------------------------------------"
    end
    if tournament_monitor.present? && !tournament_monitor.tournament.manual_assignment? && tournament_monitor.state != "closed"
      info = "+++ 8 - m6[#{id}]IGNORING table_monitor#reset_table_monitor - cannot reset managed tournament"
      Rails.logger.info info
    else
      info = "+++ 8 - m6[#{id}]table_monitor#reset_table_monitor'"
      Rails.logger.info info
      save!
      force_ready! # unless new_record?
      assign_attributes(tournament_monitor: nil, game_id: nil, nnn: nil, panel_state: "pointer_mode", data: {})
      save!
    end
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    raise StandardError
  end
end
