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

  # Flag to skip callbacks during batch operations (e.g. start_game)
  attr_accessor :skip_update_callbacks

  after_update_commit lambda {
    # Skip callbacks if flag is set (used in start_game to prevent redundant job enqueues)
    return if skip_update_callbacks
    
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
    
    # Broadcast Tournament Status Update wenn sich Spielstände während des Turniers ändern
    if tournament_monitor.is_a?(TournamentMonitor) && 
       tournament_monitor.tournament.present? &&
       tournament_monitor.tournament.tournament_started &&
       previous_changes.key?("data")
      # Prüfe ob sich relevante Spiel-Daten geändert haben
      old_data = previous_changes["data"][0] rescue {}
      new_data = previous_changes["data"][1] rescue {}
      
      # Prüfe ob result oder innings_redo_list sich geändert haben
      data_changed = false
      %w[playera playerb].each do |role|
        old_result = old_data.dig(role, "result").to_i rescue 0
        new_result = new_data.dig(role, "result").to_i rescue 0
        old_inning = Array(old_data.dig(role, "innings_redo_list")).last.to_i rescue 0
        new_inning = Array(new_data.dig(role, "innings_redo_list")).last.to_i rescue 0
        
        if old_result != new_result || old_inning != new_inning
          data_changed = true
          Rails.logger.info "TournamentStatusUpdate: Data changed for #{role} - result: #{old_result}->#{new_result}, inning: #{old_inning}->#{new_inning}"
          break
        end
      end
      
      if data_changed
        tournament = tournament_monitor.tournament
        Rails.logger.info "TournamentStatusUpdate: Triggering update for tournament #{tournament.id}"
        # Throttle: Bündele Updates mit einer Verzögerung (2 Sekunden)
        # Reduziert Server-Last bei Remote-Zugriffen
        # Mehrere schnelle Updates werden zu einem zusammengefasst
        TournamentStatusUpdateJob.set(wait: 2.seconds).perform_later(tournament)
      end
    end
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
    
    # Return empty string if role is nil or not valid
    return "".html_safe if role.nil? || !data.key?(role)
    
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
    
    # Return empty string if role is nil or not valid
    return "".html_safe if role.nil? || !data.key?(role)
    
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
      foul = show_innings_fouls[ix].to_i
      ret << (foul.zero? ? "<span class=\"inline-block px-1\">#{i}</span>" : "<span class=\"inline-block px-1\">#{i},F#{foul}</span>")
    end
    Array(data[role].andand["innings_redo_list"]).reverse.each_with_index do |i, ix|
      ret << (ix.zero? ? "<strong class=\"border-4 border-solid border-gray-400 p-1 inline-block mx-1\">#{i}</strong>" : "<span class=\"inline-block px-1\">#{i}</span>").to_s
    end
    if ret.length > last_n
      "#{prefix}...#{ret[-last_n..].join(", ")}".html_safe
    else
      (prefix.to_s + ret.join(", ")).html_safe
    end
  rescue StandardError => e
    Rails.logger.error "ERROR in render_last_innings: #{e.class}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace&.first(10)&.join("\n")}"
    Rails.logger.error "Data: role=#{role}, innings_list=#{data[role].andand['innings_list'].inspect}, innings_redo_list=#{data[role].andand['innings_redo_list'].inspect}"
    Tournament.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError, "render_last_innings failed: #{e.message}" unless Rails.env == "production"
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
  
  def protocol_modal_should_be_open?
    panel_state == "protocol" || panel_state == "protocol_edit"
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    false
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
    
    # Disable callbacks during start_game to prevent redundant background jobs
    # (start_game does 3 saves which would trigger 6 background jobs otherwise)
    self.skip_update_callbacks = true
    
    # Unlink any existing game from this table monitor (preserve game history)
    if game.present?
      existing_game_id = game.id
      game.update(table_monitor: nil)
      Rails.logger.info "Unlinked existing game #{existing_game_id} from table monitor #{id}" if DEBUG
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
    
    # Re-enable callbacks and manually enqueue table_scores job
    # (full_screen_update is NOT needed because controller does redirect_to @table_monitor)
    self.skip_update_callbacks = false
    TableMonitorJob.perform_later(self, "table_scores")
    
    finish_warmup! if options["discipline_a"] =~ /shootout/i && may_finish_warmup?
    true
  rescue StandardError => e
    msg = "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    Rails.logger.info msg if DEBUG
    self.skip_update_callbacks = false  # Ensure callbacks are re-enabled on error
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

  # Game Protocol Modal - Get innings history for both players
  def innings_history
    Rails.logger.warn "=" * 80
    Rails.logger.warn "📋 INNINGS_HISTORY_DEBUG 📋 START for TableMonitor #{id}"
    
    gps = game&.game_participations&.order(:role).to_a
    
    # Get completed and current innings (FIX: Handle empty arrays correctly!)
    innings_list_a = Array(data.dig('playera', 'innings_list'))
    innings_redo_a = Array(data.dig('playera', 'innings_redo_list'))
    innings_redo_a = [0] if innings_redo_a.empty?
    
    innings_list_b = Array(data.dig('playerb', 'innings_list'))
    innings_redo_b = Array(data.dig('playerb', 'innings_redo_list'))
    innings_redo_b = [0] if innings_redo_b.empty?
    
    innings_counter_a = data.dig('playera', 'innings').to_i
    innings_counter_b = data.dig('playerb', 'innings').to_i
    
    # Get active player
    active_player = data.dig('current_inning', 'active_player')
    
    Rails.logger.warn "📋 INNINGS_HISTORY_DEBUG 📋 INPUT DATA:"
    Rails.logger.warn "  Player A: counter=#{innings_counter_a}, list=#{innings_list_a.inspect}, redo=#{innings_redo_a.inspect}"
    Rails.logger.warn "  Player B: counter=#{innings_counter_b}, list=#{innings_list_b.inspect}, redo=#{innings_redo_b.inspect}"
    Rails.logger.warn "  Active player: #{active_player}"
    
    # Number of rows = completed innings + 1 for current inning
    # An inning is only complete when BOTH players have played
    # So we use MIN, not MAX of the list lengths
    completed_innings = [innings_list_a.length, innings_list_b.length].min
    num_rows = completed_innings + 1
    num_rows = [num_rows, 1].max  # At least 1
    
    Rails.logger.warn "📋 INNINGS_HISTORY_DEBUG 📋 CALCULATION:"
    Rails.logger.warn "  completed_innings (MIN of list lengths) = #{completed_innings}"
    Rails.logger.warn "  num_rows (completed + 1) = #{num_rows}"
    
    # Build arrays with EXACTLY num_rows
    innings_a = []
    innings_b = []
    
    (0...num_rows).each do |i|
      # For Player A at row i
      if i < innings_list_a.length
        # Completed inning from list
        innings_a << innings_list_a[i]
      elsif i == innings_list_a.length && (active_player == 'playera' || data.dig('playera', 'innings').to_i > innings_list_a.length)
        # Current inning from redo_list - only if A is active OR A's innings counter is ahead
        innings_a << (innings_redo_a[0] || 0)
      else
        # Not yet started or other player is active - empty/nil
        innings_a << nil
      end
      
      # For Player B at row i
      if i < innings_list_b.length
        # Completed inning from list
        innings_b << innings_list_b[i]
      elsif i == innings_list_b.length && (active_player == 'playerb' || data.dig('playerb', 'innings').to_i > innings_list_b.length)
        # Current inning from redo_list - only if B is active OR B's innings counter is ahead
        innings_b << (innings_redo_b[0] || 0)
      else
        # Not yet started or other player is active - empty/nil
        innings_b << nil
      end
    end
    
    # Calculate running totals from the complete innings arrays
    # Skip nil values (player hasn't played that inning yet)
    totals_a = []
    totals_b = []
    sum_a = 0
    sum_b = 0
    innings_a.each_with_index do |points, i|
      if points.nil?
        totals_a << nil
      else
        sum_a += points.to_i
        totals_a << sum_a
      end
    end
    innings_b.each_with_index do |points, i|
      if points.nil?
        totals_b << nil
      else
        sum_b += points.to_i
        totals_b << sum_b
      end
    end
    
    Rails.logger.warn "📋 INNINGS_HISTORY_DEBUG 📋 RESULT:"
    Rails.logger.warn "  Player A innings (#{innings_a.length} items): #{innings_a.inspect}"
    Rails.logger.warn "  Player B innings (#{innings_b.length} items): #{innings_b.inspect}"
    Rails.logger.warn "  Will display #{[innings_a.length, innings_b.length].max} rows in protocol"
    Rails.logger.warn "📋 INNINGS_HISTORY_DEBUG 📋 END"
    Rails.logger.warn "=" * 80
    
    {
      player_a: {
        name: gps[0]&.player&.fullname || "Spieler A",
        shortname: gps[0]&.player&.shortname || "Spieler A",
        innings: innings_a,
        totals: totals_a,
        result: data.dig('playera', 'result').to_i,
        innings_count: data.dig('playera', 'innings').to_i
      },
      player_b: {
        name: gps[1]&.player&.fullname || "Spieler B",
        shortname: gps[1]&.player&.shortname || "Spieler B",
        innings: innings_b,
        totals: totals_b,
        result: data.dig('playerb', 'result').to_i,
        innings_count: data.dig('playerb', 'innings').to_i
      },
      current_inning: {
        number: num_rows,  # Current inning = number of rows
        active_player: data.dig('current_inning', 'active_player')
      },
      discipline: data.dig('playera', 'discipline'),
      balls_goal: data.dig('playera', 'balls_goal').to_i
    }
  rescue StandardError => e
    Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
    {
      player_a: { name: 'Spieler A', innings: [], totals: [], result: 0, innings_count: 0 },
      player_b: { name: 'Spieler B', innings: [], totals: [], result: 0, innings_count: 0 },
      current_inning: { number: 1, active_player: 'playera' },
      discipline: '',
      balls_goal: 0
    }
  end

  # Update innings history from game protocol modal
  def update_innings_history(innings_params)
    Rails.logger.info "-----------m6[#{id}]---------->>> update_innings_history <<<------------------------------------------" if DEBUG
    
    return { success: false, error: 'Not in playing state' } unless playing? || set_over?
    
    begin
      new_playera_innings = innings_params['playera'] || []
      new_playerb_innings = innings_params['playerb'] || []
      
      # Validate: no negative values allowed
      if new_playera_innings.any? { |v| v.to_i < 0 } || new_playerb_innings.any? { |v| v.to_i < 0 }
        return { success: false, error: 'Negative Punktzahlen sind nicht erlaubt' }
      end
      
      # Read both arrays first
      innings_a = new_playera_innings.map(&:to_i)
      innings_b = new_playerb_innings.map(&:to_i)
      
      # Current number of rows shown in modal is max(innings_a, innings_b)
      current_rows = [data.dig('playera', 'innings').to_i, data.dig('playerb', 'innings').to_i].max
      
      # Determine the actual number of played innings for each player
      # by looking at the existing data structure (not the sent arrays)
      # The sent arrays include empty cells as 0, which we need to interpret correctly
      
      # Get the actual current structure from the data
      current_list_a = data.dig('playera', 'innings_list') || []
      current_redo_a = data.dig('playera', 'innings_redo_list') || [0]
      current_list_b = data.dig('playerb', 'innings_list') || []
      current_redo_b = data.dig('playerb', 'innings_redo_list') || [0]
      active_player = data.dig('current_inning', 'active_player')
      
      # Calculate how many rows each player ACTUALLY has (list + redo if not empty or active)
      actual_rows_a = current_list_a.length + (current_redo_a[0] != 0 || active_player == 'playera' ? 1 : 0)
      actual_rows_b = current_list_b.length + (current_redo_b[0] != 0 || active_player == 'playerb' ? 1 : 0)
      
      # The new rows should be based on how many non-zero values we have in the sent data
      # BUT: keep at least actual_rows to not accidentally delete
      new_rows_a = innings_a.length
      new_rows_b = innings_b.length
      
      # Don't count trailing zeros UNLESS it's the active player's current inning
      if new_rows_a > actual_rows_a
        # More rows sent - check if last is just trailing zero
        while innings_a.last == 0 && new_rows_a > actual_rows_a
          innings_a.pop
          new_rows_a -= 1
        end
      end
      
      if new_rows_b > actual_rows_b
        while innings_b.last == 0 && new_rows_b > actual_rows_b
          innings_b.pop
          new_rows_b -= 1
        end
      end
      
      # Determine new innings number
      new_rows = [new_rows_a, new_rows_b].max
      
      # Only change innings if the number of rows changed (INSERT/DELETE)
      if new_rows != current_rows
        # Structure changed - update both players to the same innings number
        data['playera']['innings'] = new_rows
        data['playerb']['innings'] = new_rows
      end
      
      # Now distribute values using the (possibly updated) innings numbers
      current_innings_a = data['playera']['innings']
      current_innings_b = data['playerb']['innings']
      
      # Distribute values for Player A
      if innings_a.length >= current_innings_a && current_innings_a > 0
        # Split at current innings position
        data['playera']['innings_list'] = innings_a[0...(current_innings_a - 1)]
        data['playera']['innings_redo_list'] = [innings_a[current_innings_a - 1] || 0]
      elsif innings_a.length < current_innings_a
        # Not enough values - fill what we can
        data['playera']['innings_list'] = innings_a[0...(current_innings_a - 1)] || []
        data['playera']['innings_redo_list'] = [innings_a[current_innings_a - 1] || 0]
      else
        # current_innings_a is 0 or invalid
        data['playera']['innings_list'] = []
        data['playera']['innings_redo_list'] = innings_a.empty? ? [0] : [innings_a[0]]
      end
      
      data['playera']['result'] = innings_a.sum
      data['playera']['hs'] = innings_a.max || 0
      data['playera']['gd'] = if current_innings_a > 0
                                format("%.3f", data['playera']['result'].to_f / current_innings_a)
                              else
                                0.0
                              end
      
      # Adjust foul lists to match structure
      target_length_a = [data['playera']['innings_list'].length, 0].max
      current_fouls_a = (data['playera']['innings_foul_list'] || [])[0...target_length_a]
      data['playera']['innings_foul_list'] = current_fouls_a + Array.new([target_length_a - current_fouls_a.length, 0].max, 0)
      data['playera']['innings_foul_redo_list'] = [0]
      
      # Distribute values for Player B
      if innings_b.length >= current_innings_b && current_innings_b > 0
        data['playerb']['innings_list'] = innings_b[0...(current_innings_b - 1)]
        data['playerb']['innings_redo_list'] = [innings_b[current_innings_b - 1] || 0]
      elsif innings_b.length < current_innings_b
        data['playerb']['innings_list'] = innings_b[0...(current_innings_b - 1)] || []
        data['playerb']['innings_redo_list'] = [innings_b[current_innings_b - 1] || 0]
      else
        data['playerb']['innings_list'] = []
        data['playerb']['innings_redo_list'] = innings_b.empty? ? [0] : [innings_b[0]]
      end
      
      data['playerb']['result'] = innings_b.sum
      data['playerb']['hs'] = innings_b.max || 0
      data['playerb']['gd'] = if current_innings_b > 0
                                format("%.3f", data['playerb']['result'].to_f / current_innings_b)
                              else
                                0.0
                              end
      
      # Adjust foul lists to match structure
      target_length_b = [data['playerb']['innings_list'].length, 0].max
      current_fouls_b = (data['playerb']['innings_foul_list'] || [])[0...target_length_b]
      data['playerb']['innings_foul_list'] = current_fouls_b + Array.new([target_length_b - current_fouls_b.length, 0].max, 0)
      data['playerb']['innings_foul_redo_list'] = [0]
      
      # Mark data as changed and save
      data_will_change!
      save!
      
      { success: true }
    rescue StandardError => e
      Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
      { success: false, error: e.message }
    end
  end

  # Protocol editing methods for GameProtocolReflex
  
  # Increment points for a specific inning and player
  def increment_inning_points(inning_index, player)
    return unless playing? || set_over?
    
    innings_list = Array(data[player]['innings_list'])
    innings_redo_list = Array(data[player]['innings_redo_list'])
    innings_redo_list = [0] if innings_redo_list.empty?
    
    Rails.logger.warn "🔍 INCREMENT: inning_index=#{inning_index}, innings_list.length=#{innings_list.length}"
    
    # Determine if we're editing a completed inning (in innings_list) or the current inning (in innings_redo_list)
    if inning_index < innings_list.length
      # Editing a completed inning
      Rails.logger.warn "🔍 INCREMENT: Editing completed inning at index #{inning_index}"
      innings_list[inning_index] = (innings_list[inning_index] || 0) + 1
    elsif inning_index == innings_list.length
      # Editing the current inning
      Rails.logger.warn "🔍 INCREMENT: Editing current inning (redo_list)"
      innings_redo_list[0] = (innings_redo_list[0] || 0) + 1
    else
      Rails.logger.error "🔍 INCREMENT: Invalid inning_index #{inning_index} (list length=#{innings_list.length})"
      return
    end
    
    # Update the data
    data[player]['innings_list'] = innings_list
    data[player]['innings_redo_list'] = innings_redo_list
    
    # Recalculate result, hs, gd
    recalculate_player_stats(player)
  end
  
  # Decrement points for a specific inning and player
  def decrement_inning_points(inning_index, player)
    return unless playing? || set_over?
    
    innings_list = Array(data[player]['innings_list'])
    innings_redo_list = Array(data[player]['innings_redo_list'])
    innings_redo_list = [0] if innings_redo_list.empty?
    
    # Determine if we're editing a completed inning or the current inning
    if inning_index < innings_list.length
      # Editing a completed inning
      innings_list[inning_index] = [(innings_list[inning_index] || 0) - 1, 0].max
    elsif inning_index == innings_list.length
      # Editing the current inning
      innings_redo_list[0] = [(innings_redo_list[0] || 0) - 1, 0].max
    else
      return
    end
    
    # Update the data
    data[player]['innings_list'] = innings_list
    data[player]['innings_redo_list'] = innings_redo_list
    
    # Recalculate result, hs, gd
    recalculate_player_stats(player)
  end
  
  # Delete an inning (only if both players have 0 points AND not the current inning)
  def delete_inning(inning_index)
    return { success: false, error: 'Not in playing state' } unless playing? || set_over?
    
    Rails.logger.warn "🗑️ DELETE_DEBUG 🗑️ Trying to delete inning at index #{inning_index}"
    
    # Get current lists for both players
    innings_list_a = Array(data.dig('playera', 'innings_list'))
    innings_list_b = Array(data.dig('playerb', 'innings_list'))
    
    Rails.logger.warn "🗑️ DELETE_DEBUG 🗑️ innings_list_a.length=#{innings_list_a.length}, innings_list_b.length=#{innings_list_b.length}"
    
    # Check if trying to delete the CURRENT inning (last row = innings_redo_list)
    max_list_length = [innings_list_a.length, innings_list_b.length].max
    if inning_index >= max_list_length
      Rails.logger.warn "🗑️ DELETE_DEBUG 🗑️ REJECTED: Cannot delete current inning (index=#{inning_index} >= list_length=#{max_list_length})"
      return { success: false, error: 'Die laufende Aufnahme kann nicht gelöscht werden' }
    end
    
    # Check if both players have 0 points in this inning
    value_a = innings_list_a[inning_index] || 0
    value_b = innings_list_b[inning_index] || 0
    
    Rails.logger.warn "🗑️ DELETE_DEBUG 🗑️ Values at index #{inning_index}: A=#{value_a}, B=#{value_b}"
    
    if value_a != 0 || value_b != 0
      Rails.logger.warn "🗑️ DELETE_DEBUG 🗑️ REJECTED: Values not 0:0"
      return { success: false, error: 'Nur Zeilen mit 0:0 können gelöscht werden' }
    end
    
    # Remove the inning from both innings_lists
    innings_list_a.delete_at(inning_index)
    innings_list_b.delete_at(inning_index)
    
    Rails.logger.warn "🗑️ DELETE_DEBUG 🗑️ After delete: innings_list_a=#{innings_list_a.inspect}, innings_list_b=#{innings_list_b.inspect}"
    
    # Update the data
    data['playera']['innings_list'] = innings_list_a
    data['playerb']['innings_list'] = innings_list_b
    
    # Decrement innings counter for both players (min 1)
    data['playera']['innings'] = [data['playera']['innings'].to_i - 1, 1].max
    data['playerb']['innings'] = [data['playerb']['innings'].to_i - 1, 1].max
    
    Rails.logger.warn "🗑️ DELETE_DEBUG 🗑️ New innings counters: A=#{data['playera']['innings']}, B=#{data['playerb']['innings']}"
    
    # Recalculate stats for both players
    recalculate_player_stats('playera', save_now: false)
    recalculate_player_stats('playerb', save_now: false)
    
    data_will_change!
    save!
    
    Rails.logger.warn "🗑️ DELETE_DEBUG 🗑️ SUCCESS"
    { success: true }
  rescue StandardError => e
    Rails.logger.error "🗑️ DELETE_DEBUG 🗑️ ERROR: #{e.message}"
    { success: false, error: e.message }
  end
  
  # Insert an empty inning before the specified index for BOTH players
  def insert_inning(before_index)
    return unless playing? || set_over?
    
    Rails.logger.warn "=" * 80
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯 START - before_index=#{before_index}"
    Rails.logger.warn "=" * 80
    
    # Get current lists for both players
    innings_list_a = Array(data.dig('playera', 'innings_list'))
    innings_redo_a = Array(data.dig('playera', 'innings_redo_list'))
    innings_redo_a = [0] if innings_redo_a.empty?
    
    innings_list_b = Array(data.dig('playerb', 'innings_list'))
    innings_redo_b = Array(data.dig('playerb', 'innings_redo_list'))
    innings_redo_b = [0] if innings_redo_b.empty?
    
    innings_counter_a = data.dig('playera', 'innings').to_i
    innings_counter_b = data.dig('playerb', 'innings').to_i
    
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯 BEFORE INSERT:"
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯   Player A: innings_counter=#{innings_counter_a}, innings_list=#{innings_list_a.inspect}, innings_redo_list=#{innings_redo_a.inspect}"
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯   Player B: innings_counter=#{innings_counter_b}, innings_list=#{innings_list_b.inspect}, innings_redo_list=#{innings_redo_b.inspect}"
    
    # Combine list + redo to get full current arrays
    full_a = innings_list_a + innings_redo_a
    full_b = innings_list_b + innings_redo_b
    
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯 COMBINED ARRAYS (before insert):"
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯   full_a (#{full_a.length} items) = #{full_a.inspect}"
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯   full_b (#{full_b.length} items) = #{full_b.inspect}"
    
    # Insert 0 at the specified position for BOTH players
    full_a.insert(before_index, 0)
    full_b.insert(before_index, 0)
    
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯 AFTER INSERT AT INDEX #{before_index}:"
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯   full_a (#{full_a.length} items) = #{full_a.inspect}"
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯   full_b (#{full_b.length} items) = #{full_b.inspect}"
    
    # Increment innings counter for both players
    data['playera']['innings'] = (data['playera']['innings'].to_i + 1)
    data['playerb']['innings'] = (data['playerb']['innings'].to_i + 1)
    
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯 INNINGS COUNTERS: A=#{data['playera']['innings']}, B=#{data['playerb']['innings']}"
    
    # Split back into list and redo
    # The last element is always redo, everything before is list
    if full_a.length > 1
      data['playera']['innings_list'] = full_a[0...-1]
      data['playera']['innings_redo_list'] = [full_a.last]
    else
      data['playera']['innings_list'] = []
      data['playera']['innings_redo_list'] = [full_a.first || 0]
    end
    
    if full_b.length > 1
      data['playerb']['innings_list'] = full_b[0...-1]
      data['playerb']['innings_redo_list'] = [full_b.last]
    else
      data['playerb']['innings_list'] = []
      data['playerb']['innings_redo_list'] = [full_b.first || 0]
    end
    
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯 AFTER SPLIT BACK TO LIST + REDO:"
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯   Player A: innings_list=#{data['playera']['innings_list'].inspect}, innings_redo_list=#{data['playera']['innings_redo_list'].inspect}"
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯   Player B: innings_list=#{data['playerb']['innings_list'].inspect}, innings_redo_list=#{data['playerb']['innings_redo_list'].inspect}"
    
    # Recalculate stats for both players (defer save until both are done)
    recalculate_player_stats('playera', save_now: false)
    recalculate_player_stats('playerb', save_now: false)
    
    # Save once after both players are updated
    data_will_change!
    save!
    
    # DEBUG: Show what innings_history will return (what the UI will display)
    history = innings_history
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯 FINAL STATE (what UI will show):"
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯   Player A innings: #{history[:player_a][:innings].inspect}"
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯   Player B innings: #{history[:player_b][:innings].inspect}"
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯   Number of rows: #{[history[:player_a][:innings].length, history[:player_b][:innings].length].max}"
    Rails.logger.warn "🎯 INSERT_DEBUG 🎯 END"
    Rails.logger.warn "=" * 80
  end

  private
  
  # Recalculate player stats (result, hs, gd) based on current innings_list and innings_redo_list
  # Does NOT modify the innings structure, only the calculated stats
  # Optional: pass save_now=false to defer saving (useful when updating multiple players)
  def recalculate_player_stats(player, save_now: true)
    innings_list = Array(data[player]['innings_list'])
    innings_redo_list = Array(data[player]['innings_redo_list'])
    innings_redo_list = [0] if innings_redo_list.empty?
    current_innings = data[player]['innings'].to_i
    
    # Calculate result (only completed innings)
    data[player]['result'] = innings_list.compact.sum
    
    # Calculate HS (high score) from all innings (completed + current)
    all_innings = innings_list + innings_redo_list
    data[player]['hs'] = all_innings.compact.max || 0
    
    # Calculate GD (average) from all innings
    total_points = all_innings.compact.sum
    data[player]['gd'] = if current_innings > 0
                            format("%.3f", total_points.to_f / current_innings)
                          else
                            0.0
                          end
    
    Rails.logger.warn "🔍 RECALC: player=#{player}, result=#{data[player]['result']}, hs=#{data[player]['hs']}, gd=#{data[player]['gd']}"
    
    if save_now
      data_will_change!
      save!
    end
  end
  
  # Update innings data for a player from a complete innings array
  def update_player_innings_data(player, innings_array)
    current_innings = data[player]['innings'].to_i
    
    Rails.logger.warn "🔍 UPDATE_PLAYER: player=#{player}, current_innings=#{current_innings}, innings_array=#{innings_array.inspect}"
    
    # Split into innings_list (completed) and innings_redo_list (current)
    if current_innings > 0 && innings_array.length >= current_innings
      data[player]['innings_list'] = innings_array[0...(current_innings - 1)]
      data[player]['innings_redo_list'] = [innings_array[current_innings - 1] || 0]
    else
      data[player]['innings_list'] = []
      data[player]['innings_redo_list'] = [innings_array.first || 0]
    end
    
    Rails.logger.warn "🔍 UPDATE_PLAYER: Split into list=#{data[player]['innings_list'].inspect}, redo=#{data[player]['innings_redo_list'].inspect}"
    
    # Update result (total score) - ONLY from completed innings (innings_list), NOT including current inning (innings_redo_list)
    # The scoreboard adds innings_redo_list separately, so we must not include it here
    data[player]['result'] = data[player]['innings_list'].compact.sum
    
    Rails.logger.warn "🔍 UPDATE_PLAYER: Setting result=#{data[player]['result']} (from innings_list=#{data[player]['innings_list'].compact.inspect}, NOT including redo=#{data[player]['innings_redo_list'].inspect})"
    
    # Update HS (high score)
    data[player]['hs'] = innings_array.compact.max || 0
    
    # Update GD (average) - use TOTAL points (including current inning) divided by innings counter
    total_points = innings_array.compact.sum
    data[player]['gd'] = if current_innings > 0
                            format("%.3f", total_points.to_f / current_innings)
                          else
                            0.0
                          end
    
    data_will_change!
    save!
  end

  # Calculate running totals for a player's innings
  def calculate_running_totals(player_id)
    innings = data.dig(player_id, 'innings_list') || []
    totals = []
    sum = 0
    innings.each do |points|
      sum += points.to_i
      totals << sum
    end
    totals
  end
end
