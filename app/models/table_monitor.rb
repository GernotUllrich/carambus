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

  # broadcasts_to ->(table_monitor) { [table_monitor, :table_show2] }, inserts_by: :prepend, updates_by: :replace

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

  # Check if this table has an active stream configuration
  def has_active_stream?
    table&.stream_configuration&.active?
  end

  before_create :on_create
  before_save :log_state_change

  delegate :name, to: :table, allow_nil: true

  # Broadcast suppression flag — set by GameSetup during batch saves
  # to prevent redundant TableMonitorJob enqueues.
  attr_writer :suppress_broadcast

  def suppress_broadcast
    @suppress_broadcast || false
  end

  after_update_commit lambda {
    # Skip callbacks if flag is set (used in start_game to prevent redundant job enqueues)
    if suppress_broadcast
      Rails.logger.info "🔔 Skipping callbacks (suppress_broadcast=true)"
      Rails.logger.info "🔔 ========== after_update_commit END (skipped) =========="
      # @collected_data_changes = nil ## ! still collect changes!
      return
    end

    # Skip cable broadcasts on API Server (no scoreboards running)
    # Local servers are identified by having a carambus_api_url configured
    unless ApplicationRecord.local_server?
      Rails.logger.info "🔔 Skipping callbacks (API Server - no scoreboards)"
      Rails.logger.info "🔔 ========== after_update_commit END (API Server) =========="
      return
    end

    Rails.logger.info "🔔 ========== after_update_commit TRIGGERED =========="
    Rails.logger.info "🔔 TableMonitor ID: #{id}"
    Rails.logger.info "🔔 Previous changes: #{@collected_changes.inspect}"
    Rails.logger.info "🔔 Previous data changes: #{@collected_data_changes.inspect}"

    # broadcast_replace_later_to self
    relevant_keys = (previous_changes.keys - %w[data nnn panel_state pointer_mode current_element updated_at])
    Rails.logger.info "🔔 Relevant keys: #{relevant_keys.inspect}"

    get_options!(I18n.locale)
    if tournament_monitor.is_a?(PartyMonitor) &&
       (relevant_keys.include?("state") || state != "playing")
      Rails.logger.info "🔔 Enqueuing: party_monitor_scores job"
      TableMonitorJob.perform_later(id,
                                    "party_monitor_scores")
    end
    # Update table_scores overview (if structural changes) OR individual teaser (if score changes only)
    if previous_changes.keys.present? && relevant_keys.present?
      Rails.logger.info "🔔 Enqueuing: table_scores job (relevant_keys present)"
      TableMonitorJob.perform_later(id, "table_scores")
      # Also send teaser for tournament_scores page (which doesn't have #table_scores container)
      Rails.logger.info "🔔 Enqueuing: teaser job (for tournament_scores page)"
      TableMonitorJob.perform_later(id, "teaser")
    elsif @collected_changes.present? || @collected_data_changes.select(&:present?).present?
      Rails.logger.info "🔔 Enqueuing: teaser job (no relevant_keys)"
      TableMonitorJob.perform_later(id, "teaser")
    end

    # ULTRA-FAST PATH: Only score/innings changed - send just data, no HTML
    if ultra_fast_score_update?
      player_key = (@collected_data_changes.flat_map(&:keys) & %w[playera playerb]).first
      TableMonitorJob.perform_later(id, "score_data", player: player_key)
      @collected_data_changes = nil
      return
    end

    # FAST PATH: Check for simple score changes that can use targeted updates
    # If only one player's score changed (plus balls_on_table), use partial update instead of full render
    if simple_score_update?
      player_key = (@collected_data_changes.flat_map(&:keys) & %w[playera playerb]).first

      Rails.logger.info "🔔 ⚡ FAST PATH: Simple score update detected for #{player_key}"
      Rails.logger.info "🔔 ⚡ Changed keys: #{@collected_data_changes.flat_map(&:keys).uniq.inspect}"
      TableMonitorJob.perform_later(id, "player_score_panel", player: player_key)

      @collected_data_changes = nil
      Rails.logger.info "🔔 ========== after_update_commit END (fast path) =========="
      return
    end

    # SLOW PATH: Full scoreboard update
    # The empty string triggers the `else` branch in TableMonitorJob's case statement,
    # which renders and broadcasts the full scoreboard HTML (#full_screen_table_monitor_X).
    # See docs/EMPTY_STRING_JOB_ANALYSIS.md for detailed explanation.
    Rails.logger.info "🔔 Enqueuing: score_update job (empty string for full screen)"
    TableMonitorJob.perform_later(id, "")
    @collected_data_changes = nil
    Rails.logger.info "🔔 ========== after_update_commit END =========="

    # Broadcast Tournament Status Update wenn sich Spielstände während des Turniers ändern
    if tournament_monitor.is_a?(TournamentMonitor) &&
       tournament_monitor.tournament.present? &&
       tournament_monitor.tournament.tournament_started &&
       previous_changes.key?("data")
      # Prüfe ob sich relevante Spiel-Daten geändert haben
      old_data = begin
        previous_changes["data"][0]
      rescue StandardError
        {}
      end
      new_data = begin
        previous_changes["data"][1]
      rescue StandardError
        {}
      end

      # Prüfe ob result oder innings_redo_list sich geändert haben
      data_changed = false
      %w[playera playerb].each do |role|
        old_result = begin
          old_data.dig(role, "result").to_i
        rescue StandardError
          0
        end
        new_result = begin
          new_data.dig(role, "result").to_i
        rescue StandardError
          0
        end
        old_inning = begin
          Array(old_data.dig(role, "innings_redo_list")).last.to_i
        rescue StandardError
          0
        end
        new_inning = begin
          Array(new_data.dig(role, "innings_redo_list")).last.to_i
        rescue StandardError
          0
        end

        next unless old_result != new_result || old_inning != new_inning

        data_changed = true
        Rails.logger.info "TournamentStatusUpdate: Data changed for #{role} - result: #{old_result}->#{new_result}, inning: #{old_inning}->#{new_inning}"
        break
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

  def ultra_fast_score_update?
    return false if @collected_data_changes.blank?
    return false if @collected_changes.present?

    # 14.1 endlos requires full updates due to complex ball display and counter stack
    return false if discipline == "14.1 endlos"

    # Flatten all keys from collected changes
    all_keys = @collected_data_changes.flat_map(&:keys).uniq

    # Ultra-fast path: ONLY score/innings changed for one player
    # Check if only one player changed and only innings_redo_list
    player_keys = all_keys & %w[playera playerb]
    return false unless player_keys.size == 1

    player_key = player_keys.first
    player_changes = @collected_data_changes.find { |c| c.key?(player_key) }
    return false unless player_changes

    # Check if only innings_redo_list changed for this player
    player_change_keys = player_changes[player_key].keys
    player_change_keys == ["innings_redo_list"]
  end

  def simple_score_update?
    return false if @collected_data_changes.blank?
    return false if @collected_changes.present?

    # 14.1 endlos requires full updates due to complex ball display and counter stack
    return false if discipline == "14.1 endlos"

    # Flatten all keys from collected changes
    all_keys = @collected_data_changes.flat_map(&:keys).uniq

    # Fast path: only balls_on_table and/or one player changed
    safe_keys = %w[balls_on_table playera playerb]
    player_keys = all_keys & %w[playera playerb]

    # Must have exactly one player key, and only safe keys
    player_keys.size == 1 && (all_keys - safe_keys).empty?
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
    "warning" => "ok",
    "protocol_final" => "confirm_result"
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

  aasm column: "state", whiny_transitions: true do
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

    # Global state transition logging to detect spurious transitions
    after_all_transitions :log_state_transition

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

  # Lazy accessor for the pure-hash ScoreEngine collaborator.
  # Invalidated on reload so the engine always wraps the freshly-loaded data hash.
  def score_engine
    return @score_engine if @score_engine
    ensure_bk_params_baked!
    @score_engine = TableMonitor::ScoreEngine.new(data, discipline: discipline)
  end

  # Phase 38.5 lifecycle invariant: guarantees BkParamResolver has populated
  # effective_discipline + the two BK params into data before any predicate reads
  # them. Re-bakes on drift — the cached effective_discipline is stale if
  # bk2_options.first_set_mode or sets.length has changed since the last bake.
  #
  # Required because predicate semantics (Phase 38.5 D-09) became strict on data
  # keys, and not every code path that brings a TableMonitor into the scoring
  # lifecycle goes through GameSetup#start_game (notably: in-flight games that
  # pre-date the deploy, detail-form edits to first_set_mode after start_game,
  # controller-driven score adjustments, validation jobs).
  #
  # Skips when free_game_form is blank (no game configured yet) so cold
  # TableMonitors aren't bake-mutated on first read. compute_effective_discipline
  # is cheap (pure hash reads, no DB) so the drift check is essentially free; the
  # actual bake (Discipline lookup + 4-level walk) only fires when needed.
  def ensure_bk_params_baked!
    return if data["free_game_form"].blank?

    expected_eff = BkParamResolver.compute_effective_discipline(self)
    return if data.key?("allow_negative_score_input") &&
              data["effective_discipline"] == expected_eff

    BkParamResolver.bake!(self)
  end

  def reload(...)
    @score_engine = nil
    super
  end

  def internal_name
    Rails.logger.debug do
      "-----------m6[#{id}]---------->>> internal_name <<<------------------------------------------"
    end
    read_attribute(:name)
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def on_create
    Rails.logger.debug { "-----------m6[#{id}]---------->>> on_create <<<------------------------------------------" }
    Rails.logger.debug { "+++ 8xxx - table_monitor#on_create" }
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
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
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def locked_scoreboard
    state == "set_over" && !player_controlled?
  end

  def log_state_change_destroy
    log_state_change
  end

  def log_state_change
    @collected_data_changes ||= []
    @collected_changes ||= []
    if changes.present?
      changes["data"]&.count == 2 && (@collected_data_changes << deep_diff(*changes["data"]))
      @collected_changes << changes.except("data") if changes.except("data").present?
    end
    Rails.logger.debug do
      "-------------m6[#{id}]-------->>> log_state_change #{changes.inspect} <<<------------------------------------------"
    end
    if state_changed?
      Rails.logger.debug { "[TableMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}" }
    end
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def remote_control_detected
    false # TODO: Test remote control and activate here
  end

  def set_game_over
    Rails.logger.debug do
      "--------------m6[#{id}]------->>> set_game_over (state=#{state}) <<<------------------------------------------"
    end

    # Only show protocol_final modal when entering set_over state ("Partie beendet - OK?")
    # Not when entering final_set_score ("Ergebnis erfasst") or final_match_score
    if state == "set_over"
      assign_attributes(panel_state: "protocol_final", current_element: "confirm_result")
      data_will_change!
      save
    end
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def numbers
    Rails.logger.debug { "-------------m6[#{id}]-------->>> numbers <<<------------------------------------------" }
    active_player = data["current_inning"].andand["active_player"]
    nnn_val = data[active_player].andand["innings_redo_list"].andand[-1].to_i
    update(nnn: nnn_val)
    Rails.logger.debug { "numbers +++++m6[#{id}]++ C: SUBMIT JOB" }
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def update_every_n_seconds(n_secs)
    Rails.logger.debug do
      "--------------------->>> update_every_n_seconds(#{n_secs}) <<<------------------------------------------"
    end
    TableMonitorClockJob.perform_later(self, n_secs, data["current_inning"]["active_player"],
                                       data[data["current_inning"]["active_player"]].andand["innings_redo_list"].andand[-1].to_i,
                                       data[data["current_inning"]["active_player"]].andand["innings"])
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def player_a_on_table_before
    Rails.logger.debug do
      "-------------m6[#{id}]-------->>> player_a_on_table_before <<<------------------------------------------"
    end
    # TODO: player_a_on_table_before
    false
  end

  def player_b_on_table_before
    Rails.logger.debug do
      "-------------m6[#{id}]-------->>> player_b_on_table_before <<<------------------------------------------"
    end
    # TODO: player_b_on_table_before
    false
  end

  def do_play
    Rails.logger.debug { "--------------m6[#{id}]------->>> do_play <<<------------------------------------------" }
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
      Rails.logger.debug do
        "[table_monitor#do_play] m6[#{id}]active_timer, start_at, finish_at: #{[active_timer, start_at,
                                                                                finish_at].inspect}"
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
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def render_innings_list(role)
    score_engine.render_innings_list(role)
  rescue StandardError => e
    Rails.logger.error "ERROR:m6[#{id}] #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end

  def automatic_next_set
    true # TODO: automatic_next_set should be an configurable attribute
  end

  def render_last_innings(last_n, role)
    score_engine.render_last_innings(last_n, role)
  rescue StandardError => e
    Rails.logger.error "ERROR in render_last_innings: #{e.class}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace&.first(10)&.join("\n")}"
    Rails.logger.error "Data: role=#{role}, innings_list=#{data[role].andand["innings_list"].inspect}, innings_redo_list=#{data[role].andand["innings_redo_list"].inspect}"
    raise StandardError, "render_last_innings failed: #{e.message}" unless Rails.env == "production"
  end

  def warmup_modal_should_be_open?
    # noinspection RubyResolve
    warmup? || warmup_a? || warmup_b?
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def shootout_modal_should_be_open?
    # noinspection RubyResolve
    match_shootout?
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def discipline
    data["playera"].andand["discipline"]
  end

  def numbers_modal_should_be_open?
    # noinspection RubyResolve
    nnn.present? || panel_state == "numbers"
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def protocol_modal_should_be_open?
    %w[protocol protocol_edit protocol_final].include?(panel_state)
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    false
  end

  def foul_modal_should_be_open?
    panel_state == "foul"
  rescue StandardError => e
    Rails.logger.error "ERROR: foul_modal_should_be_open?[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    false
  end

  def snooker_inning_edit_modal_should_be_open?
    panel_state == "snooker_inning_edit"
  rescue StandardError => e
    Rails.logger.error "ERROR: snooker_inning_edit_modal_should_be_open?[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    false
  end

  # Returns the initial number of red balls for snooker (6, 10, or 15)
  # Default is 15 (standard snooker)
  def initial_red_balls = score_engine.initial_red_balls

  # Undo the last potted ball for snooker
  # Removes last ball from protocol, recalculates score and game state
  def undo_snooker_ball(player_role) = score_engine.undo_snooker_ball(player_role)

  # Recalculate snooker state (reds_remaining, colors_sequence) from protocol
  def recalculate_snooker_state_from_protocol = score_engine.recalculate_snooker_state_from_protocol

  # Updates snooker game state when a ball is potted
  def update_snooker_state(ball_value) = score_engine.update_snooker_state(ball_value)

  # Determines which balls are "on" (playable) in snooker according to official rules
  # Returns a hash with ball values (1-7) as keys and status values:
  #   :on - ball is "on" and playable
  #   :addable - ball can be added (red after red, can pot multiple reds in same shot)
  #   :off - ball is not playable
  # Ball 1 = Red, 2 = Yellow, 3 = Green, 4 = Brown, 5 = Blue, 6 = Pink, 7 = Black
  def snooker_balls_on = score_engine.snooker_balls_on

  # Calculate remaining points on the table in a Snooker frame
  # Returns total points that can still be scored
  def snooker_remaining_points = score_engine.snooker_remaining_points

  def final_protocol_modal_should_be_open?
    panel_state == "protocol_final"
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    false
  end

  def get_progress_bar_status(n_bars)
    Rails.logger.debug do
      "------------m6[#{id}]--------->>> get_progress_bar_status(#{n_bars}) <<<------------------------------------------"
    end
    time_counter = green_bars = do_green_bars = do_yellow_bars = do_orange_bars = do_lightred_bars = do_red_bars = 0
    finish = timer_finish_at
    start = timer_start_at
    Rails.logger.debug { "[table_monitor#get_progress_bar_status] finish, start: #{[finish, start].inspect}" }
    if finish.present? && timer_halt_at.present?
      Rails.logger.debug { "[table_monitor#get_progress_bar_status] finish.present && timer_halt_at.present ..." }
      halted = Time.now.to_i - timer_halt_at.to_i
      finish += halted.seconds
      start += halted.seconds
      Rails.logger.debug do
        "[table_monitor#get_progress_bar_status] halted, finish, start: #{[halted, finish, start].inspect}"
      end
    end
    if finish.present? && (Time.now < finish)
      Rails.logger.debug { "[table_monitor#get_progress_bar_status] finish.present && Time.now < finish ..." }
      delta_total = (finish - start).to_i
      delta_rest = (finish - Time.now)
      units = active_timer =~ /min$/ ? "minutes" : "seconds"
      Rails.logger.debug do
        "[table_monitor#get_progress_bar_status] halted, finish, start: #{[delta_total, delta_rest, units].inspect}"
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
      Rails.logger.debug do
        "[table_monitor#get_progress_bar_status] m6[#{id}]time_counter, green_bars: #{[time_counter,
                                                                                       green_bars].inspect}"
      end
    end
    Rails.logger.debug do
      "[table_monitor#get_progress_bar_status] m6[#{id}]return [time_counter, green_bars]: #{[time_counter,
                                                                                              green_bars].inspect}"
    end
    [time_counter, green_bars, do_green_bars, do_yellow_bars, do_orange_bars, do_lightred_bars, do_red_bars]
  rescue StandardError => e
    Rails.logger.error "ERROR: #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end

  def switch_players
    Rails.logger.debug do
      "--------------m6[#{id}]------->>> switch_players <<<------------------------------------------"
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
      # save!
    end
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def set_start_time
    Rails.logger.debug do
      "------------m6[#{id}]--------->>> set_start_time <<<------------------------------------------"
    end
    game.update(started_at: Time.now)
  rescue StandardError => e
    Rails.logger.error "ERROR: #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end

  def set_end_time
    Rails.logger.debug do
      "-------------m6[#{id}]-------->>> set_end_time <<<------------------------------------------"
    end

    # IDEMPOTENCY: Only set end time if not already set (prevents race conditions)
    # CRITICAL: Reload game to get fresh state from DB (prevents stale reads in race conditions)
    game.reload

    if game.ended_at.blank?
      game.update(ended_at: Time.now)
      Rails.logger.info "✅ m6[#{id}] set_end_time: Game[#{game_id}] ended_at set to #{Time.now}"
    else
      Rails.logger.warn "⚠️  IDEMPOTENCY: m6[#{id}] set_end_time: Game[#{game_id}] already has ended_at=#{game.ended_at}, SKIPPING duplicate (race prevented!)"
    end
  rescue StandardError => e
    Rails.logger.error "ERROR: #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end

  def assign_game(game_p)
    TableMonitor::GameSetup.assign(table_monitor: self, game_participation: game_p)
  end

  def initialize_game
    TableMonitor::GameSetup.initialize_game(table_monitor: self)
  end

  def display_name
    Rails.logger.debug do
      "------------m6[#{id}]--------->>> display_name <<<------------------------------------------"
    end
    t_no = (name || table.name)&.match(/.*(\d+)/)&.andand&.[](1)
    I18n.t("table_monitors.display_name", t_no:)
  rescue StandardError => e
    Rails.logger.error "ERROR:m6[#{id}] #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end

  def seeding_from(role)
    Rails.logger.debug do
      "-------------m6[#{id}]-------->>> seeding_from(#{role}) <<<------------------------------------------"
    end
    # TODO: - puh can't this be easiere?
    player = game.game_participations.where(role:).first&.player
    if player.present?
      player.seedings.where("seedings.id >= #{Seeding::MIN_ID}")
            .where(tournament_id: tournament_monitor.tournament_id).first
    end
  rescue StandardError => e
    Rails.logger.error "ERROR: #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end

  def balls_left(n_balls_left)
    result = score_engine.balls_left(n_balls_left)
    data_will_change!
    self.copy_from = nil
    terminate_current_inning if result == :goal_reached
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def foul_two
    return unless playing?

    result = score_engine.foul_two
    data_will_change!
    self.copy_from = nil
    terminate_current_inning if result == :inning_terminated
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def foul_one
    return unless playing?

    result = score_engine.foul_one
    data_will_change!
    self.copy_from = nil
    terminate_current_inning if result == :inning_terminated
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def displays_clock?
    data["free_game_form"] != "pool"
  end

  # Phase 38.2 D-18 / UAT-GAP-05: signals that a BK2-Kombi TableMonitor is in
  # an inconsistent state — data["free_game_form"] flagged BK2 but bk2_state
  # is missing or empty (e.g. from pre-Plan-06 test state or manual data
  # manipulation). Consumed by _show_bk2_kombi.html.erb (Plan 03) to render a
  # fallback banner rather than a scoreboard with all-zero defaults.
  def bk2_state_uninitialized?
    return false unless data.is_a?(Hash) && data["free_game_form"] == "bk2_kombi"
    state = data["bk2_state"]
    !state.is_a?(Hash) || state.empty?
  end

  def recompute_result(current_role) = score_engine.recompute_result(current_role)

  def init_lists(current_role) = score_engine.init_lists(current_role)

  def add_n_balls(n_balls, player = nil, skip_snooker_state_update: false)
    result = score_engine.add_n_balls(n_balls, player, skip_snooker_state_update: skip_snooker_state_update)
    if result == :snooker_frame_complete
      # All snooker balls potted — persist and trigger end-of-frame evaluation
      Rails.logger.info "[add_n_balls] Snooker frame[#{game_id}] on TM[#{id}]: All balls potted, evaluating result"
      data_will_change!
      self.copy_from = nil
      save!
      evaluate_result
      return
    end
    data_will_change!
    self.copy_from = nil
    if result == :goal_reached
      # BK-Familie folgt legacy karambol-Routing. BK-spezifische Logik liegt
      # in den Guards (follow_up?, end_of_set?, score_engine).
      terminate_current_inning(player)
    end
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    Tournament.logger.info "ERROR: #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def reset_timer!
    Rails.logger.debug do
      "---------------m6[#{id}]------>>> reset_timer! <<<------------------------------------------"
    end
    assign_attributes(
      active_timer: nil,
      timer_start_at: nil,
      timer_finish_at: nil,
      timer_halt_at: nil
    )
  rescue StandardError => e
    Tournament.logger.info "#{e}, #{e.backtrace.to_a.join("\n")}"
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace.to_a.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end

  # Clear cached options after reload to ensure fresh data
  def clear_options_cache
    @cached_options = nil
    @cached_options_key = nil
  end

  def get_options!(locale)
    # Cache options per instance to avoid expensive re-computation
    # Cache-Key includes locale and updated_at timestamp
    cache_key = "#{locale}_#{updated_at.to_i}"

    return @cached_options if @cached_options && @cached_options_key == cache_key

    presenter = TableMonitor::OptionsPresenter.new(self, locale: locale)
    options = presenter.call

    # cattr assignments must stay here — OptionsPresenter is a PORO without model coupling
    self.class.options    = options
    self.class.gps        = presenter.gps
    self.class.location   = presenter.location
    self.class.tournament = presenter.show_tournament
    self.class.my_table   = presenter.my_table

    @cached_options = options
    @cached_options_key = cache_key

    options
  end

  attr_reader :msg

  def marshal_dup(hash)
    Marshal.load(Marshal.dump(hash))
  end

  def evaluate_panel_and_current
    return unless remote_control_detected

    Rails.logger.debug do
      "--------------m6[#{id}]------->>> evaluate_panel_and_current <<<------------------------------------------"
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
      new_panel_state = "protocol_final"
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
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def more_sets?
    data["sets_to_play"].to_i > 1 && (data["sets_to_win"].to_i > 1)
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  # Check if this is a multi-set match (Gewinnsätze or max. Sätze)
  def is_multi_set_match?
    data["sets_to_win"].to_i > 1 || data["sets_to_play"].to_i > 1
  end

  # Check if the match is decided (one player has won enough sets, or all sets played)
  def is_match_decided?
    return true unless is_multi_set_match?

    if data["sets_to_win"].to_i > 1
      # Gewinnsätze mode - check if someone has won enough sets
      max_number_of_wins = get_max_number_of_wins
      max_number_of_wins >= data["sets_to_win"].to_i
    elsif data["sets_to_play"].to_i > 1
      # Fixed number of sets mode - check if all sets are played
      sets_played >= data["sets_to_play"].to_i
    else
      true
    end
  end

  def set_n_balls(n_balls, change_to_pointer_mode = false)
    return unless playing?

    result = score_engine.set_n_balls(n_balls, change_to_pointer_mode)
    data_will_change!
    assign_attributes(nnn: nil, panel_state: change_to_pointer_mode ? "pointer_mode" : panel_state)
    if result == :goal_reached
      save
      # BK-Familie folgt legacy karambol-Routing.
      terminate_current_inning
    else
      save
    end
  rescue StandardError => e
    Rails.logger.error "ERROR: #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end

  def terminate_current_inning(player = nil)
    Rails.logger.debug do
      "--------------m6[#{id}]------->>> terminate_current_inning <<<------------------------------------------"
    end
    @msg = nil
    TableMonitor.transaction do
      result = score_engine.terminate_inning_data(player, playing: playing?)
      if result == :ok
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
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end

  def player_controlled?
    tournament_monitor.blank? || tournament_monitor.tournament.blank? || tournament_monitor.tournament.player_controlled?
  end

  # BK-2kombi: derived current set's discipline (DZ ↔ SP alternating from set 1).
  # Source of truth: legacy data["sets"] count + bk2_options.first_set_mode. Returns
  # nil for non-BK-2kombi games.
  def bk2_kombi_current_phase
    return nil unless data.is_a?(Hash) && data["free_game_form"] == "bk2_kombi"
    first_mode = data.dig("bk2_options", "first_set_mode").presence || "direkter_zweikampf"
    set_number = Array(data["sets"]).length + 1
    set_number.odd? ? first_mode : (first_mode == "direkter_zweikampf" ? "serienspiel" : "direkter_zweikampf")
  end

  # BK-Familie Nachstoß-Regeln (Overlay über legacy follow_up?):
  #   BK-2plus / BK50 / BK100  → NIE Nachstoß
  #   BK-2 / BK-2kombi SP-Phase + Ziel in 1. Aufnahme erreicht → legacy Nachstoß zulässig
  #   BK-2kombi DZ-Phase → NIE Nachstoß (= BK-2plus-Semantik)
  # Returns nil for non-BK disciplines (legacy logic decides).
  def bk_follow_up_override
    return nil unless data.is_a?(Hash)
    case data["free_game_form"]
    when "bk_2plus", "bk50", "bk100"
      false
    when "bk2_kombi"
      bk2_kombi_current_phase == "direkter_zweikampf" ? false : nil
    else
      nil
    end
  end

  def follow_up?
    override = bk_follow_up_override
    return false if override == false

    left_player_id = data["fixed_display_left"].blank? ? data["current_kickoff_player"] : data["current_left_player"]
    right_player_id = left_player_id == "playera" ? "playerb" : "playera"
    active_player_is_follow_up_player = (data["current_inning"].andand["active_player"] == right_player_id)
    kickoff_player_has_balls_goal = data[left_player_id].andand["balls_goal"].presence.to_i.positive?
    has_reached_balls_goal = data[left_player_id].andand["balls_goal"].presence.to_i.positive? && (data[left_player_id].andand["result"].to_i >= data[left_player_id].andand["balls_goal"].to_i)
    innings_goal_exists = data["innings_goal"].presence.to_i.positive?
    kickoff_player_has_reached_innings_goal = data["innings_goal"].presence.to_i.positive? && data[left_player_id].andand["innings"].to_i >= data["innings_goal"].to_i
    ret = data.present? &&
          active_player_is_follow_up_player &&
          ((kickoff_player_has_balls_goal && has_reached_balls_goal) ||
            (innings_goal_exists && kickoff_player_has_reached_innings_goal))

    # Erste-Aufnahme-Gate für BK-2 und BK-2kombi/SP: Nachstoß nur wenn Anstoß-Spieler
    # das Ziel in seiner 1. Aufnahme erreicht hat. Wer erst in 2.+ Aufnahme zum Ziel
    # kommt, hat seine Tisch-Zeit gehabt und der Gegner bekommt keinen Ausgleich.
    if ret && %w[bk_2 bk2_kombi].include?(data["free_game_form"])
      ret = data[left_player_id].andand["innings"].to_i == 1
    end

    Rails.logger.debug do
      "+++++ FOLLOW_UP? returns #{ret}: (active_player_is_follow_up_player:#{active_player_is_follow_up_player} && (kickoff_player_has_balls_goal:#{kickoff_player_has_balls_goal} && has_reached_balls_goal:#{has_reached_balls_goal} || (innings_goal_exists:#{innings_goal_exists} && kickoff_player_has_reached_innings_goal:#{kickoff_player_has_reached_innings_goal}))"
    end
    ret
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def redo
    Rails.logger.debug { "----------------m6[#{id}]----->>> redo <<<------------------------------------------" }
    return unless playing?

    current_role = data["current_inning"]["active_player"]

    # For "14.1 endlos" discipline, use PaperTrail-based redo
    if data[current_role]["discipline"] == "14.1 endlos"
      return unless copy_from.present?

      next_copy_from = copy_from + 1
      if next_copy_from <= versions.last.index
        next_version = versions[next_copy_from]
        if next_version
          self.copy_from = next_copy_from
          deep_merge_data!(next_version.reify.data)
          data_will_change!
          save!
        end
      end
      return
    end

    # If we're in an undone state, restore forward through versions first
    if copy_from.present? && copy_from < versions.last.index
      next_copy_from = copy_from + 1
      next_version = versions.find_by(index: next_copy_from)
      if next_version
        self.copy_from = next_copy_from
        deep_merge_data!(next_version.reify.data)
        data_will_change!
        save!
        return
      end
    end

    # For other disciplines: delegate hash-based redo to ScoreEngine
    result = score_engine.redo_hash
    return unless result == :inning_terminated

    terminate_current_inning
  end

  def can_redo?
    return false unless playing?

    current_role = data["current_inning"]["active_player"]

    # For "14.1 endlos", check if copy_from allows redo
    return copy_from.present? && copy_from < versions.last.index if data[current_role]["discipline"] == "14.1 endlos"

    # For other disciplines, check if there's a current inning with points or undone state
    innings_redo = Array(data[current_role]["innings_redo_list"]).last.to_i
    return true if innings_redo.positive?
    return true if copy_from.present? && copy_from < versions.last.index

    false
  end

  def can_undo?
    return false unless playing? || set_over?

    current_role = data["current_inning"]["active_player"]

    # For "14.1 endlos", check if we can go back
    if data[current_role]["discipline"] == "14.1 endlos"
      # Can undo if we have versions and either copy_from is set or we have game data
      return true if copy_from.present? && copy_from.positive?
      return true if versions.any? && (data["playera"]["innings"].to_i + data["playerb"]["innings"].to_i +
        data["playera"]["result"].to_i + data["playerb"]["result"].to_i +
        data["sets"].to_a.length +
        data["playera"]["innings_redo_list"].andand[-1].to_i + data["playerb"]["innings_redo_list"].andand[-1].to_i).positive?

      return false
    end

    # For other disciplines, check if we have innings to undo
    the_other_player = (current_role == "playera" ? "playerb" : "playera")
    return true if data[the_other_player]["innings"].to_i.positive?
    return true if copy_from.present? && copy_from.positive?
    return true if versions.any? && (data["playera"]["innings"].to_i + data["playerb"]["innings"].to_i +
      data["playera"]["result"].to_i + data["playerb"]["result"].to_i +
      data["sets"].to_a.length +
      data["playera"]["innings_redo_list"].andand[-1].to_i + data["playerb"]["innings_redo_list"].andand[-1].to_i).positive?

    false
  end

  def undo
    Rails.logger.debug { "-----------------m6[#{id}]---->>> undo <<<------------------------------------------" }
    if playing? || set_over?
      current_role = data["current_inning"]["active_player"]
      if data[current_role]["discipline"] == "14.1 endlos"
        # PaperTrail-based undo for 14.1 endlos — stays in TableMonitor
        if (data["playera"]["innings"].to_i + data["playerb"]["innings"].to_i +
          data["playera"]["result"].to_i + data["playerb"]["result"].to_i +
          data["sets"].to_a.length +
          data["playera"]["innings_redo_list"].andand[-1].to_i + data["playerb"]["innings_redo_list"].andand[-1].to_i).zero?
          self.state = "match_shootout"
        elsif copy_from.present?
          copy_from_ = copy_from - 1
          prev_version = versions[copy_from_].reify
          prev_version.copy_from = copy_from_
          prev_version.save!
          reload
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
        end
      elsif set_over?
        # PaperTrail-based undo for set_over state — stays in TableMonitor
        version = versions[-3]
        tt = version.reify
        tt.copy_from = version.index
        tt.save!
        reload
      elsif simple_set_game? && data["sets"].present?
        # PaperTrail-based undo for multi-set games — stays in TableMonitor
        play_versions = if copy_from.present?
                          versions.where("whodunnit ilike '%in `switch_to_next_set''%'").select do |v|
                            v.index < copy_from
                          end
                        else
                          versions.where("whodunnit ilike '%in `switch_to_next_set''%'")
                        end
        p_version = PaperTrail::Version[play_versions[-2].id + 1]
        copy_from_ = p_version.index
        prev_version = p_version.reify
        prev_version.copy_from = copy_from_
        prev_version.save!
        reload
      else
        # Non-PaperTrail hash mutation — delegate to ScoreEngine
        score_engine.undo_hash
        data_will_change!
        save!
      end
    else
      @msg = "Game Finished - no more inputs allowed"
      nil
    end
  rescue StandardError => e
    Tournament.logger.info "#{e}, #{e.backtrace&.join("\n")}"
    Rails.logger.error "ERROR: #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end

  # Delegation zu TableMonitor::ResultRecorder (extrahiert in Phase 05-01)

  def save_result
    TableMonitor::ResultRecorder.save_result(table_monitor: self)
  end

  def save_current_set
    TableMonitor::ResultRecorder.save_current_set(table_monitor: self)
  end

  def get_max_number_of_wins
    TableMonitor::ResultRecorder.get_max_number_of_wins(table_monitor: self)
  end

  def sets_played
    data["ba_results"].andand["Sets1"].to_i + data["ba_results"].andand["Sets2"].to_i
  end

  def switch_to_next_set
    TableMonitor::ResultRecorder.switch_to_next_set(table_monitor: self)
  end

  def evaluate_result
    TableMonitor::ResultRecorder.call(table_monitor: self)
  end

  def start_game(options_ = {})
    TableMonitor::GameSetup.call(table_monitor: self, options: options_)
  end

  def revert_players
    Rails.logger.debug do
      "--------------m6[#{id}]------->>> revert_players <<<------------------------------------------"
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
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def end_of_set?
    # GUARD: Game must have actually been played before it can end
    # Prevent spurious finalization of games that haven't started
    total_innings = data["playera"]["innings"].to_i + data["playerb"]["innings"].to_i
    total_points = data["playera"]["result"].to_i + data["playerb"]["result"].to_i

    # For Snooker: also count points in innings_redo_list (where snooker break points accumulate)
    if data["free_game_form"] == "snooker"
      total_redo_points = (data["playera"]["innings_redo_list"]&.last.to_i + data["playerb"]["innings_redo_list"]&.last.to_i)
      total_points += total_redo_points
    end

    if total_innings.zero? && total_points.zero?
      Rails.logger.warn "[TableMonitor#end_of_set?] GUARD: Game[#{game_id}] on TM[#{id}] has 0 innings and 0 points - NOT ending set (state: #{state})"
      return false
    end

    # Snooker: Frame ends when all balls are potted and flag is set
    # Flag is set in add_n_balls when last ball is potted
    # This prevents frame ending on player switch after last ball
    if data["free_game_form"] == "snooker"
      frame_complete = data["snooker_frame_complete"] || false
      if frame_complete
        Rails.logger.info "[TableMonitor#end_of_set?] Snooker frame[#{game_id}] on TM[#{id}] ended: frame_complete flag set (A:#{data["playera"]["result"]}, B:#{data["playerb"]["result"]})"
        return true
      end
      return false
    end

    # BK-Familie: Disziplin/Phase-spezifischer Override des innings-equal/allow_follow_up
    # Gates. In Phasen ohne Nachstoß (BK-2plus, BK-2kombi DZ-Phase, BK50, BK100) muss
    # bei Zielerreichung SOFORT geschlossen werden — kein Warten auf gleiche Aufnahmen.
    # In Phasen MIT Nachstoß (BK-2, BK-2kombi SP) bleibt die legacy-Logik aktiv (wartet
    # auf Anstoßspieler-Aufnahmen-Parität, was natürlich der ein-Aufnahme-Nachstoß ist).
    no_followup_phase = case data["free_game_form"]
                        when "bk_2plus", "bk50", "bk100" then true
                        when "bk2_kombi" then bk2_kombi_current_phase == "direkter_zweikampf"
                        else false
                        end
    if no_followup_phase && data["playera"]["balls_goal"].to_i.positive? &&
        (data["playera"]["result"].to_i >= data["playera"]["balls_goal"].to_i ||
         data["playerb"]["result"].to_i >= data["playerb"]["balls_goal"].to_i)
      Rails.logger.info "[TableMonitor#end_of_set?] BK-immediate-close: #{data["free_game_form"]} #{bk2_kombi_current_phase} — A:#{data["playera"]["result"]}/#{data["playera"]["balls_goal"]} B:#{data["playerb"]["result"]}/#{data["playerb"]["balls_goal"]}"
      return true
    end

    # Phase 38.7 Plan 02 — D-02 BK-2 / BK-2kombi-SP Nachstoss-Aufnahme close.
    # SKILL extend-before-build: small guard on legacy predicate, NO parallel state machine.
    #
    # When BK-2 (or BK-2kombi in SP-Phase) and Anstoss-Spieler reached balls_goal,
    # the Nachstoss-Spieler gets ONE extra inning. After he completes that inning,
    # the set MUST close — regardless of whether he reached balls_goal too. The
    # legacy gate `playera.innings == playerb.innings` only fires for the case
    # where Nachstoss did NOT reach the goal (he plays an inning that ends with
    # `current_inning.active_player` switching back). When Nachstoss DOES reach
    # the goal, his inning counter ticks +1, gate fails, deadlock.
    #
    # Resolution: detect "Anstoss-Spieler at goal AND Nachstoss-Spieler in his
    # post-Anstoss-goal inning AND innings asymmetry of exactly 1". Fire close.
    # If both at goal -> tiebreak (Plan 04 detects, modal opens). If only Anstoss
    # at goal -> normal win (legacy path).
    bk_with_nachstoss = data["free_game_form"] == "bk_2" ||
                        (data["free_game_form"] == "bk2_kombi" && bk2_kombi_current_phase == "serienspiel")
    if bk_with_nachstoss && data["playera"]["balls_goal"].to_i.positive?
      a_result = data["playera"]["result"].to_i
      b_result = data["playerb"]["result"].to_i
      goal = data["playera"]["balls_goal"].to_i
      # Identify which side is Anstoss-Spieler — the one with kickoff role.
      # Use current_kickoff_player when present, else fall back to "playera".
      anstoss_role = data["current_kickoff_player"].presence || "playera"
      nachstoss_role = anstoss_role == "playera" ? "playerb" : "playera"
      anstoss_innings = data[anstoss_role]["innings"].to_i
      nachstoss_innings = data[nachstoss_role]["innings"].to_i
      anstoss_at_goal = data[anstoss_role]["result"].to_i >= goal
      nachstoss_finished_followup = nachstoss_innings == anstoss_innings + 1
      if anstoss_at_goal && nachstoss_finished_followup
        Rails.logger.info "[TableMonitor#end_of_set?] D-02 BK-2-Nachstoss-close: " \
          "form=#{data["free_game_form"]} anstoss=#{anstoss_role}(#{a_result}/#{anstoss_innings}) " \
          "nachstoss=#{nachstoss_role}(#{b_result}/#{nachstoss_innings}) goal=#{goal}"
        return true
      end
    end

    if data["playera"]["balls_goal"].to_i.positive? && (data["playera"]["result"].to_i >= data["playera"]["balls_goal"].to_i ||
      data["playerb"]["result"].to_i >= data["playerb"]["balls_goal"].to_i) &&
       (data["playera"]["innings"] == data["playerb"]["innings"] || !data["allow_follow_up"])
      Rails.logger.info "[TableMonitor#end_of_set?] Game[#{game_id}] on TM[#{id}] ended: balls_goal reached (A:#{data["playera"]["result"]}/#{data["playera"]["balls_goal"]}, B:#{data["playerb"]["result"]}/#{data["playerb"]["balls_goal"]})"
      return true
    elsif data["innings_goal"].to_i.positive? && data["playera"]["innings"].to_i >= data["innings_goal"].to_i &&
          (data["playera"]["innings"] == data["playerb"]["innings"] || !data["allow_follow_up"])
      Rails.logger.info "[TableMonitor#end_of_set?] Game[#{game_id}] on TM[#{id}] ended: innings_goal reached (A:#{data["playera"]["innings"]}, B:#{data["playerb"]["innings"]}, goal:#{data["innings_goal"]})"
      return true
    end

    false
  rescue StandardError => e
    Rails.logger.error "ERROR: #{e}, #{e.backtrace&.join("\n")}"
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
    Rails.logger.error "ERROR: #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end

  def deep_delete!(key, do_save = true)
    Rails.logger.debug do
      "--------------m6[#{id}]------->>> deep_delete!(#{key}, #{do_save}) <<<------------------------------------------"
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
    Rails.logger.error "ERROR: #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end

  def prepare_final_game_result
    Rails.logger.debug do
      "--------------m6[#{id}]------->>> prepare_final_game_result <<<------------------------------------------"
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
      # Save results to the game for both free games and tournament/party games
      if final_set_score? && game.present?
        game.deep_merge_data!("ba_results" => data["ba_results"])
        game.save!
        Rails.logger.debug { "[prepare_final_game_result] Saved ba_results to game #{game.id}" }
      end
    else
      Rails.logger.info "[prepare_final_game_result] m6[#{id}]ignored - no game"
    end
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def simple_set_game?
    (data["free_game_form"] == "pool" && data["playera"]["discipline"] != "14.1 endlos") ||
      data["free_game_form"] == "snooker"
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
      Rails.logger.debug { "nxst +++++ B: %i[warmup warmup_a warmup_b].include?(state.to_sym)" }
      reset_timer!
      # noinspection RubyResolve
      finish_warmup!
    elsif [:match_shootout].include?(state.to_sym)
      Rails.logger.debug { "nxst +++++ C: [:match_shootout].include?(state.to_sym)" }
      reset_timer!
      finish_shootout!
    elsif set_over? || final_match_score?
      Rails.logger.debug { "nxst +++++ D: set_over? || final_match_score?" }
      evaluate_result
      # acknowledge_result!
      # prepare_final_game_result
    elsif final_set_score?
      Rails.logger.debug { "nxst +++++ E: final_set_score?" }
      if tournament_monitor.present?
        Rails.logger.debug { "nxst +++++ F: tournament_monitor.present?" }
        evaluate_result
        # tournament_monitor.report_result(@table_monitor)
      else
        Rails.logger.debug { "nxst +++++ G: ! tournament_monitor.present?" }
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
    Rails.logger.debug do
      "--------------m6[#{id}]------->>> reset_table_monitor <<<------------------------------------------"
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
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  # Game Protocol Modal - Get innings history for both players
  def innings_history
    gps = game&.game_participations&.order(:role).to_a || []
    score_engine.innings_history(gps: gps)
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    {
      player_a: { name: "Spieler A", innings: [], totals: [], result: 0, innings_count: 0 },
      player_b: { name: "Spieler B", innings: [], totals: [], result: 0, innings_count: 0 },
      current_inning: { number: 1, active_player: "playera" },
      discipline: "",
      balls_goal: 0
    }
  end

  # Update innings history from game protocol modal
  def update_innings_history(innings_params)
    Rails.logger.debug do
      "-----------m6[#{id}]---------->>> update_innings_history <<<------------------------------------------"
    end
    result = score_engine.update_innings_history(innings_params, playing_or_set_over: playing? || set_over?)
    return result unless result[:success]

    data_will_change!
    save!
    result
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    { success: false, error: e.message }
  end

  # Protocol editing methods for GameProtocolReflex

  # Increment points for a specific inning and player
  def increment_inning_points(inning_index, player)
    return unless playing? || set_over?

    score_engine.increment_inning_points(inning_index, player)
    data_will_change!
    save!
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
  end

  # Decrement points for a specific inning and player
  def decrement_inning_points(inning_index, player)
    return unless playing? || set_over?

    score_engine.decrement_inning_points(inning_index, player)
    data_will_change!
    save!
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
  end

  # Delete an inning (only if both players have 0 points AND not the current inning)
  def delete_inning(inning_index)
    return { success: false, error: "Not in playing state" } unless playing? || set_over?

    result = score_engine.delete_inning(inning_index, playing_or_set_over: true)
    return result unless result[:success]

    data_will_change!
    save!
    result
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
    { success: false, error: e.message }
  end

  # Insert an empty inning before the specified index for BOTH players
  def insert_inning(before_index)
    return unless playing? || set_over?

    score_engine.insert_inning(before_index, playing_or_set_over: true)
    data_will_change!
    save!
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
  end

  private

  # Update innings data for a player from a complete innings array
  def update_player_innings_data(player, innings_array)
    score_engine.update_player_innings_data(player, innings_array)
    data_will_change!
    save!
  rescue StandardError => e
    Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
  end

  # Calculate running totals for a player's innings
  def calculate_running_totals(player_id)
    score_engine.calculate_running_totals(player_id)
  end

  # Log all state transitions to detect spurious state changes
  def log_state_transition
    from_state = aasm.from_state
    to_state = aasm.to_state
    event_name = aasm.current_event

    # Get temporary values from TableMonitor data hash
    temp_innings = begin
      data["playera"]["innings"].to_i + data["playerb"]["innings"].to_i
    rescue StandardError
      0
    end
    temp_points = begin
      data["playera"]["result"].to_i + data["playerb"]["result"].to_i
    rescue StandardError
      0
    end

    # Get actual DB values - depends on the event
    db_innings = 0
    db_points = 0
    mismatch = false

    if game.present?
      game.reload # Ensure fresh data

      # For finish_match! event, check game.data (where we write results)
      # For other events, check game_participations (updated later)
      if event_name.to_s == "finish_match!"
        # Check game.data["ba_results"] - this is where write_game_result_data writes to
        ba_results = game.data&.dig("ba_results")
        if ba_results.present?
          db_innings = ba_results["Aufnahmen1"].to_i + ba_results["Aufnahmen2"].to_i
          db_points = ba_results["Ergebnis1"].to_i + ba_results["Ergebnis2"].to_i
          mismatch = temp_innings != db_innings || temp_points != db_points
        else
          # No ba_results in game.data yet - this is a problem for finish_match!
          mismatch = temp_innings.positive? || temp_points.positive?
        end
      else
        # For other events (end_of_set!, acknowledge_result!, etc.)
        # it's NORMAL that game_participations are not yet updated
        # So we only log info, no mismatch warning
        gps = game.game_participations.reload
        if gps.any?
          db_innings = gps.map { |gp| gp.innings.to_i }.sum
          db_points = gps.map { |gp| gp.result.to_i }.sum
        end
        # Don't flag as mismatch for non-finish events
        mismatch = false
      end
    end

    if mismatch
      Rails.logger.warn "[⚠️  DATA MISMATCH] TM[#{id}] Game[#{game_id}]: #{from_state} → #{to_state} (event: #{event_name}) - TEMP: #{temp_innings}i/#{temp_points}p vs DB: #{db_innings}i/#{db_points}p (POSSIBLE RACE CONDITION!)"
    else
      Rails.logger.info "[🔄 STATE TRANSITION] TM[#{id}] Game[#{game_id}]: #{from_state} → #{to_state} (event: #{event_name}, TEMP: #{temp_innings}i/#{temp_points}p, DB: #{db_innings}i/#{db_points}p)"
    end

    # ALERT: Suspicious state transitions - only for finish_match! to final_match_score
    if event_name.to_s == "finish_match!" && to_state.to_s == "final_match_score" && temp_innings.zero? && temp_points.zero?
      Rails.logger.error "[⚠️  SUSPICIOUS TRANSITION] TM[#{id}] Game[#{game_id}] moved to #{to_state} with ZERO temp data! Event: #{event_name}, Caller: #{caller[0..3].join(" <- ")}"
    end
  rescue StandardError => e
    Rails.logger.error "[log_state_transition ERROR] #{e.message}: #{e.backtrace&.first(3)&.join(" <- ")}"
  end
end
