# frozen_string_literal: true

# == Schema Information
#
# Table name: table_monitors
#
#  id                    :bigint           not null, primary key
#  active_timer          :string
#  current_element       :string           default("pointer_mode"), not null
#  data                  :text
#  ip_address            :string
#  name                  :string
#  nnn                   :integer
#  panel_state           :string           default("pointer_mode"), not null
#  state                 :string
#  timer_finish_at       :datetime
#  timer_halt_at         :datetime
#  timer_start_at        :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  clock_job_id          :string
#  game_id               :integer
#  next_game_id          :integer
#  timer_job_id          :string
#  tournament_monitor_id :integer
#
class TableMonitor < ApplicationRecord

  cattr_accessor :allow_change_tables

  include AASM
  belongs_to :tournament_monitor, optional: true
  belongs_to :game, optional: true
  has_one :table, dependent: :nullify
  has_paper_trail

  before_create :on_create
  before_save :log_state_change

  delegate :name, to: :table, allow_nil: true

  DEFAULT_ENTRY = {
    'inputs' => 'numbers',
    'pointer_mode' => 'pointer_mode',
    'shootout' => 'start_game',
    'timer' => 'play', # depends on state !
    'setup' => 'continue',
    'numbers' => 'number_field',
    'game_finished' => 'game_state',
    'game_show_result' => 'game_state',
    'game_result_reported' => 'game_state',
    'ready_for_new_game' => 'game_state',
    'show_results' => 'game_state',
    'warning' => 'ok'
  }.freeze
  NNN = 'db' # store nnn in database table_monitor

  serialize :data, Hash
  { "state" => "game_setup_started", # ["game_setup_started", "game_shootout_started", "playing_game", "game_show_result", "game_finished", "game_result_reported"]
    "current_set" => 1,
    "sets_to_win" => 2,
    "sets_to_play" => 3,
    "kickoff_switches_with_set" => true,
    "fixed_display_left": nil,
    "color_remains_with_set" => true,
    "allow_overflow" => false,
    "allow_follow_up" => true,
    "current_kickoff_player" => "playera",
    "current_left_player" => "playera",
    "current_left_color" => "white",
    "data" =>
      { "innings_goal" => "20",
        "playera" =>
          { "result" => 0,
            "innings" => 0,
            "innings_list" => [],
            "innings_redo_list" => [],
            "hs" => 0,
            "gd" => 0.0,
            "balls_goal" => "100",
            "tc" => 0,
            "discipline" => "Freie Partie klein" },
        "playerb" =>
          { "result" => 0,
            "innings" => 0,
            "innings_list" => [],
            "innings_redo_list" => [],
            "hs" => 0,
            "gd" => 0.0,
            "balls_goal" => "100",
            "tc" => 0,
            "discipline" => "Freie Partie klein" },
        "current_inning" => { "active_player" => "playera", "balls" => 0 },
        "timeouts" => 0,
        "timeout" => 0, }
  }

  # TODO: I18n

  aasm column: 'state' do
    state :new_table_monitor, initial: true, after_enter: [:reset_table_monitor]
    state :ready
    state :game_setup_started
    state :game_warmup_a_started
    state :game_warmup_b_started
    state :game_shootout_started
    state :playing_game, after_enter: [:set_start_time], after_exit: [:set_end_time]
    state :game_show_result, after_enter: [:set_game_show_result]
    state :game_finished, after_enter: [:set_game_show_result]
    state :game_result_reported, after_enter: [:set_game_show_result]
    state :ready_for_new_game # previous game result still displayed here - and probably next players
    event :start_new_game do
      transitions from: %i[ready ready_for_new_game game_setup_started game_result_reported game_finished],
                  to: :game_setup_started, after_enter: [:initialize_game]
    end
    event :result_accepted do
      transitions from: %i[playing_game game_result_reported ready_for_new_game], to: :ready_for_new_game
    end
    event :event_play_warm_up_a do
      transitions from: %i[game_setup_started game_warmup_b_started game_warmup_a_started],
                  to: :game_warmup_a_started
    end
    event :event_play_warm_up_b do
      transitions from: %i[game_setup_started game_warmup_a_started game_warmup_b_started],
                  to: :game_warmup_b_started
    end
    event :event_warmup_finished do
      transitions from: %i[ready game_shootout_started game_setup_started game_warmup_a_started game_warmup_b_started],
                  to: :game_shootout_started
    end
    event :event_shootout_finished do
      transitions from: :game_shootout_started, to: :playing_game
    end
    event :event_game_show_result do
      transitions from: :playing_game, to: :game_show_result
    end
    event :event_set_result_accepted do
      transitions from: :game_show_result, to: :game_finished
    end
    event :event_game_result_reported do
      transitions from: %i[game_result_reported game_finished], to: :game_result_reported
    end
    event :we_re_ready do
      transitions from: %i[new_table_monitor game_result_reported], to: :ready
    end
    event :force_we_re_ready do
      transitions to: :ready
    end
  end

  def internal_name
    read_attribute(:name)
  end

  def on_create
    info = '+++ 8xxx - table_monitor#on_create'; DebugInfo.instance.update(info: info); Rails.logger.info info
  end

  def state_display(locale)
    @locale = locale || I18n.default_locale
    @game_or_set = data['sets_to_play'].to_i > 1 ? I18n.t("table_monitor.set_finished") : I18n.t("table_monitor.game_finished")
    if state == 'game_show_result'
      I18n.t('table_monitor.status.game_show_result', game_or_set_finished: @game_or_set,
             wait_check: player_controlled? ? 'OK?' : I18n.t('table_monitor.status.wait_check'))
    else
      I18n.t("table_monitor.status.#{state}")
    end
  end

  def log_state_change
    if state_changed?
      #Tournament.logger.info "[TableMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]} #{caller.select{|s| s.include?("/app/")}.join("\n")}"
      Tournament.logger.info "[TableMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}"
    end
  end

  def set_game_show_result
    update(current_element: 'game_state')
  end

  after_save do
    if previous_changes["id"].nil? && previous_changes.present?
      Tournament.logger.warn "+++ after_commit table_monitor[#{id}] #{previous_changes.inspect}"
      reload.evaluate_panel_and_current
      if changes.present?
        Tournament.logger.warn "+++ after_commit evaluate_panel_and_current table_monitor[#{id}] #{changes.inspect}"
        save
      else
        TableMonitorJob.perform_later(self)
      end
    end
  end

  def numbers
    active_player = data['current_inning'].andand['active_player']
    nnn_val = data[active_player].andand['innings_redo_list'].andand[-1].to_i
    update(nnn: nnn_val)
    TableMonitorJob.perform_later(self)
  end

  def update_every_n_seconds(n)
    TableMonitorClockJob.perform_later(self, n, data['current_inning']['active_player'],
                                  data[data['current_inning']['active_player']].andand['innings_redo_list'].andand[-1].to_i, data[data['current_inning']['active_player']].andand['innings'])
  end

  def player_a_on_table_before
    false
  end

  def player_b_on_table_before
    false
  end

  def do_play
    return unless tournament_monitor_id.present? || data['timeout'].to_i.positive?

    active_timer = 'timeout'
    units = 'seconds'
    start_at = Time.now
    delta = tournament_monitor.andand.tournament.andand.send(active_timer.to_sym).andand.send(units.to_sym) || (data['timeout'].to_i.positive? ? data['timeout'].to_i.seconds : nil)
    finish_at = delta.present? ? start_at + delta.to_i : nil
    if timer_halt_at.present? && finish_at.present?
      extend = Time.now - timer_halt_at
      start_at = timer_start_at + extend
      finish_at = timer_finish_at + extend
    end
    Rails.logger.info "[table_monitor#do_play] active_timer, start_at, finish_at: #{[active_timer, start_at, finish_at].inspect}"
    update(
      active_timer: active_timer,
      timer_halt_at: nil,
      timer_start_at: start_at,
      timer_finish_at: finish_at
    )
    update_every_n_seconds(10)
  end

  def render_innings_list(role)
    innings = data['playera']['innings'].to_i
    cols = [(innings / 15.0).ceil, 2].max
    show_innings = Array(data[role].andand['innings_list'])
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
      ret << '<th>Aufn</th><th>Pkt</th><th>∑</th>'
    end
    ret << '</tr></thead><tbody>'
    sum = 0
    sums = []
    show_innings.each_with_index do |inning, ix|
      sum += inning
      sums[ix] = sum
    end
    (0..14).each do |ix|
      ret << '<tr>'
      (1..cols).each_with_index do |_col, icol|
        ret << "<td><span class=\"sm:text-xs lg:text-lg sm:px-2 lg:px-4\">#{ix + 1 + (icol * 15)}</span></td>
<td><span class=\"sm:text-xs lg:text-lg sm:px-2 lg:px-4\">#{(ix + (icol * 15)) == sums.length ? 'GD' : show_innings[ix + (icol * 15)]}</span></td>
<td><span class=\"sm:text-xs lg:text-lg sm:px-2 lg:px-4\">#{
          if (ix + (icol * 15)) == sums.length
            format('%0.2f',
                   (sums.last.to_i / innings.to_f))
          else
            (ix + (icol * 15)) == sums.length - 1 ? "<strong class=\"text-3vw\">#{sums[ix + (icol * 15)]}</strong>" : sums[ix + (icol * 15)]
          end}</span></td>"
      end
      ret << '</tr>'
    end
    ret << '</tbody></table>'
    ret.join("\n").html_safe
  end

  def render_last_innings(n, role)
    player_ix = role == "playera" ? 1 : 2
    show_innings = Array(data[role].andand['innings_list'])
    prefix = ""
    if data["sets_to_play"].to_i > 1
      # S1:0, S2:20
      Array(data["sets"]).each_with_index do |set, ix|
        prefix += "S#{ix+1}: #{set["Ergebnis#{player_ix}"]}, "
      end
    end
    ret = show_innings.dup
    Array(data[role].andand['innings_redo_list']).reverse.each_with_index do |i, ix|
      ret << (ix.zero? ? "<strong class=\"border-2 border-green-600 p-1\">#{i}</strong>" : i.to_s).to_s
    end
    if ret.length > n
      "#{prefix}...#{ret[-n..].join('-')}".html_safe
    else
      ("#{prefix}" + ret.join('-')).html_safe
    end
  end

  def setup_modal_should_be_open?
    # noinspection RubyResolve
    game_setup_started? || game_warmup_a_started? || game_warmup_b_started?
  end

  def shootout_modal_should_be_open?
    # noinspection RubyResolve
    game_shootout_started?
  end

  def numbers_modal_should_be_open?
    # noinspection RubyResolve
    nnn.present? || panel_state == 'numbers'
  end

  def get_progress_bar_status(n)
    time_counter = green_bars = do_green_bars = do_yellow_bars = do_orange_bars = do_lightred_bars = do_red_bars = 0
    finish = timer_finish_at
    start = timer_start_at
    Rails.logger.info "[table_monitor#get_progress_bar_status] finish, start: #{[finish, start].inspect}"
    if finish.present? && timer_halt_at.present?
      Rails.logger.info "[table_monitor#get_progress_bar_status] finish.present && timer_halt_at.present ..."
      halted = Time.now - timer_halt_at
      finish += halted
      start += halted
      Rails.logger.info "[table_monitor#get_progress_bar_status] halted, finish, start: #{[halted, finish, start].inspect}"
    end
    if finish.present? && (Time.now < finish)
      Rails.logger.info "[table_monitor#get_progress_bar_status] finish.present && Time.now < finish ..."
      delta_total = (finish - start).to_i
      delta_rest = (finish - Time.now)
      units = active_timer =~ /min$/ ? 'minutes' : 'seconds'
      Rails.logger.info "[table_monitor#get_progress_bar_status] halted, finish, start: #{[delta_total, delta_rest, units].inspect}"
      if units == 'minutes'
        minutes = (delta_rest / 1.send(units)).to_i
        seconds = ((((delta_rest / 1.send(units)) - (delta_rest.to_i / 1.send(units))) * 100 * 60 / 100).to_i + 100).to_s[-2..]
        time_counter = "#{minutes}:#{seconds}"
      else
        time_counter = (1.0 * delta_rest / 1.send(units)).ceil
      end
      green_bars = [((1.0 * n * delta_rest) / delta_total).ceil, 18].min
      do_bars = [((1.0 * 50 * delta_rest) / delta_total).ceil, 50].min
      do_green_bars = [[do_bars - 40, 10].min, 0].max
      do_yellow_bars = [[do_bars - 30, 10].min, 0].max
      do_orange_bars = [[do_bars - 20, 10].min, 0].max
      do_lightred_bars = [[do_bars - 10, 10].min, 0].max
      do_red_bars = [[do_bars, 10].min, 0].max
      Rails.logger.info "[table_monitor#get_progress_bar_status] time_counter, green_bars: #{[time_counter, green_bars].inspect}"
    end
    Rails.logger.info "[table_monitor#get_progress_bar_status] return [time_counter, green_bars]: #{[time_counter, green_bars].inspect}"
    [time_counter, green_bars, do_green_bars, do_yellow_bars, do_orange_bars, do_lightred_bars, do_red_bars]
  end

  def switch_players
    if game.present?
      roles = game.game_participations.map(&:role).reverse
      game.game_participations.each_with_index do |gp, ix|
        gp.update(role: roles[ix])
      end
      ret_a = data['playerb'].dup
      ret_b = data['playera'].dup
      deep_merge_data!({
                         'current_kickoff_player' => 'playera',
                         'current_left_player' => 'playera',
                         'current_left_color' => 'white',
                         'playera' => ret_a,
                         'playerb' => ret_b
                       })
    end
  end

  def set_start_time
    game.update(started_at: Time.now)
    ClockJob.perform_later(game.table_monitor, 5)
  end

  def set_end_time
    game.update(ended_at: Time.now)
  end

  def assign_game(game_p)
    info = '+++ 8c - tournament_monitor#assign_game - game_p'
    DebugInfo.instance.update(info: info); Rails.logger.info info
    info = '+++ 8d - tournament_monitor#assign_game - table_monitor'
    DebugInfo.instance.update(info: info); Rails.logger.info info
    self.allow_change_tables = tournament_monitor.andand.allow_change_tables
    tmp_results = game_p.deep_delete!('tmp_results')
    if tmp_results.andand['state'].present?
      info = '+++ 8e - tournament_monitor#assign_game - table_monitor'
      DebugInfo.instance.update(info: info); Rails.logger.info info
      state = tmp_results.delete('state')
      deep_merge_data!(tmp_results)
      update(game_id: game_p.id, state: state)
    else
      update(game_id: game_p.id, state: 'ready')
      reload
      info = '+++ 8f - tournament_monitor#assign_game - table_monitor'
      DebugInfo.instance.update(info: info); Rails.logger.info info
      initialize_game
      save!
      if %i[ready ready_for_new_game game_setup_started game_result_reported
            game_finished].include?(self.state.to_sym)
        info = '+++ 8g - tournament_monitor#assign_game - start_new_game'
        DebugInfo.instance.update(info: info); Rails.logger.info info
        # noinspection RubyResolve
        start_new_game!
      end
    end
  end

  def initialize_game
    info = '+++ 7 - table_monitor#initialize_game'; DebugInfo.instance.update(info: info); Rails.logger.info info
    current_kickoff_player = 'playera'
    deep_merge_data!({
                       'current_kickoff_player' => current_kickoff_player,
                       'current_left_player' => current_kickoff_player,
                       'current_left_color' => 'white',
                       'allow_overflow' => tournament_monitor.andand.allow_overflow,
                       'kickoff_switches_with_set' => tournament_monitor.andand.kickoff_switches_with_set || tournament_monitor.andand.tournament.andand.kickoff_switches_with_set,
                       'allow_follow_up' => tournament_monitor.andand.allow_follow_up || tournament_monitor.andand.tournament.andand.allow_follow_up,
                       'sets_to_win' => tournament_monitor.andand.sets_to_win || tournament_monitor.andand.tournament.andand.sets_to_win,
                       'sets_to_play' => tournament_monitor.andand.sets_to_play || tournament_monitor.andand.tournament.andand.sets_to_play,
                       'team_size' => tournament_monitor.andand.team_size || tournament_monitor.andand.tournament.andand.team_size,
                       'innings_goal' =>
                         tournament_monitor.andand.innings_goal ||
                           tournament_monitor.andand.tournament.andand.innings_goal,
                       'playera' => {
                         'result' => 0,
                         'innings' => 0,
                         'innings_list' => [],
                         'innings_redo_list' => [],
                         'hs' => 0,
                         'gd' => 0.0,
                         'balls_goal' =>
                           data['result'].andand['playera'].andand['balls_goal'] ||
                             tournament_monitor.andand.tournament.andand.handicap_tournier? && seeding_from('playera').balls_goal.presence ||
                             tournament_monitor.andand.balls_goal ||
                             tournament_monitor.andand.tournament.andand.balls_goal,
                         'tc' =>
                           tournament_monitor.andand.timeouts ||
                             tournament_monitor.andand.tournament.andand.timeouts ||
                             0
                       },
                       'playerb' => {
                         'result' => 0,
                         'innings' => 0,
                         'innings_list' => [],
                         'innings_redo_list' => [],
                         'hs' => 0,
                         'gd' => 0.0,
                         'balls_goal' =>
                           data['result'].andand['playerb'].andand['balls_goal'] ||
                             tournament_monitor.andand.tournament.andand.handicap_tournier? && seeding_from('playerb').balls_goal.presence ||
                             tournament_monitor.andand.balls_goal ||
                             tournament_monitor.andand.tournament.andand.balls_goal,
                         'tc' =>
                           tournament_monitor.andand.timeouts ||
                             tournament_monitor.andand.tournament.andand.timeouts ||
                             0
                       },
                       'current_inning' => {
                         'active_player' => current_kickoff_player,
                         'balls' => 0
                       }
                     })
    # self.panel_state = "pointer_mode"
    # self.current_element = "pointer_mode"
    # event_warmup_finished! #TODO  INTERMEDIATE SOLUTION UNTIL SHOOTOUT WORKS
    data.except!("ba_results", "sets")
  end

  def display_name
    t_no = (name || table.name).andand.match(/.*(\d+)/).andand[1]
    I18n.t('table_monitors.display_name', t_no: t_no)
  end

  def seeding_from(role)
    # TODO: - puh can't this be easiere?
    game.game_participations.where(role: role).first
        .player.seedings.where("seedings.id >= #{Seeding::MIN_ID}").where(tournament_id: tournament_monitor.tournament_id).first
  end

  def add_n_balls(n)
    @msg = nil
    #noinspection RubyResolve
    if playing_game?
      current_role = data['current_inning']['active_player']
      data[current_role]['innings_redo_list'] = [0] if data[current_role]['innings_redo_list'].blank?
      to_play = data[current_role].andand['balls_goal'].to_i <= 0 ? 99_999 : data[current_role].andand['balls_goal'].to_i - (data[current_role].andand['result'].to_i + data[current_role]['innings_redo_list'][-1].to_i)
      if n <= to_play || data["allow_overflow"].present?
        add = [n, to_play].min
        data[current_role]['innings_redo_list'][-1] =
          [(data[current_role]['innings_redo_list'][-1].to_i + add), 0].max
        if add == to_play
          data_will_change!
          save
          terminate_current_inning
        else
          # data[current_role]["innings_redo_list"].pop if Array(data[current_role]["innings_redo_list"]).last.to_i > 10000
          data_will_change!
        end
      end
      # update(
      #   panel_state: "pointer_mode",
      #   current_element: "pointer_mode")
    else
      @msg = 'Game Finished - no more inputs allowed'
      nil
    end
  rescue StandardError => e
    Tournament.logger.info "#{e}, #{e.backtrace.to_a.join("\n")}"
  end

  def reset_timer!
    assign_attributes(
      active_timer: nil,
      timer_start_at: nil,
      timer_finish_at: nil,
      timer_halt_at: nil
    )
  rescue StandardError => e
    Tournament.logger.info "#{e}, #{e.backtrace.to_a.join("\n")}"
  end

  attr_reader :msg

  def evaluate_panel_and_current
    element_to_panel_state = {
      'undo' => 'inputs',
      'minus_one' => 'inputs',
      'minus_ten' => 'inputs',
      'next_step' => 'inputs',
      'add_ten' => 'inputs',
      'add_one' => 'inputs',
      'numbers' => 'inputs',
      'pause' => 'timer',
      'play' => 'timer',
      'stop' => 'timer',
      'pointer_mode' => 'pointer_mode',
      'number_field' => 'numbers',
      'nnn_1' => 'numbers',
      'nnn_2' => 'numbers',
      'nnn_3' => 'numbers',
      'nnn_4' => 'numbers',
      'nnn_5' => 'numbers',
      'nnn_6' => 'numbers',
      'nnn_7' => 'numbers',
      'nnn_8' => 'numbers',
      'nnn_9' => 'numbers',
      'nnn_0' => 'numbers',
      'nnn_del' => 'numbers',
      'nnn_enter' => 'numbers',
      'nnn_esc' => 'numbers',
      'start_game' => 'shootout',
      'change' => 'shootout',
      'continue' => 'setup',
      'practice_a' => 'setup',
      'practice_b' => 'setup'
    }
    new_panel_state = nil
    #noinspection RubyResolve
    if setup_modal_should_be_open?
      new_panel_state = 'setup'
    elsif shootout_modal_should_be_open?
      new_panel_state = 'shootout'
    elsif numbers_modal_should_be_open?
      new_panel_state = 'numbers'
    elsif game_show_result? || game_finished?
      new_panel_state = 'show_results'
    end
    if new_panel_state.present?
      new_current_element = TableMonitor::DEFAULT_ENTRY[new_panel_state]
      if new_panel_state == 'timer'
        new_current_element = timer_finish_at.present? && timer_halt_at.blank? ? 'pause' : 'play'
      end
    else
      new_panel_state = panel_state
      new_current_element = current_element
    end
    assign_attributes(panel_state: new_panel_state,
                      current_element: element_to_panel_state[new_current_element] == new_panel_state ? new_current_element : TableMonitor::DEFAULT_ENTRY[panel_state])
  end

  def more_sets?
    data["sets_to_play"].to_i > 1 && (data["sets_to_win"].to_i > 1)
  end

  def set_n_balls(n_balls, change_to_pointer_mode = false)
    @msg = nil
    if playing_game?
      current_role = data['current_inning']['active_player']
      data[current_role]['innings_redo_list'] = [0] if data[current_role]['innings_redo_list'].empty?
      to_play = data[current_role].andand['balls_goal'].to_i <= 0 ? 99_999 : data[current_role].andand['balls_goal'].to_i - data[current_role].andand['result'].to_i
      set = [n_balls.to_i, to_play.to_i].min
      data[current_role]['innings_redo_list'][-1] = set
      data_will_change!
      assign_attributes(nnn: nil, panel_state: change_to_pointer_mode ? 'pointer_mode' : panel_state)
      terminate_current_inning if set == to_play
    else
      @msg = 'Game Finished - no more inputs allowed'
      nil
    end
  end

  def terminate_current_inning
    @msg = nil
    current_role = data['current_inning']['active_player']
    if playing_game? && (data['innings_goal'].to_i.zero? || data[current_role]['innings'].to_i < data['innings_goal'].to_i)
      n_balls = Array(data[current_role]['innings_redo_list']).pop.to_i
      data[current_role]['innings_list'] ||= []
      data[current_role]['innings_redo_list'] ||= []
      data[current_role]['innings_list'] << n_balls
      data[current_role]['result'] = data[current_role]['innings_list'].sum
      if data['innings_goal'].to_i.zero? || data[current_role]['innings'].to_i < data['innings_goal'].to_i
        data[current_role]['innings'] += 1
      end
      data[current_role]['hs'] = n_balls if n_balls > data[current_role]['hs'].to_i
      data[current_role]['gd'] = format('%.2f', data[current_role]['result'].to_f / data[current_role]['innings'])
      other_player = current_role == 'playera' ? 'playerb' : 'playera'
      data['current_inning']['active_player'] = other_player
      data[other_player]['innings_redo_list'] = [0] if data[current_role]['innings_redo_list'].empty?
      data_will_change!
      save
      evaluate_result
    else
      @msg = 'Game Finished - no more inputs allowed'
      nil
    end
  rescue StandardError => e
    Tournament.logger.info "#{e}, #{e.backtrace.join("\n")}"
  end

  def player_controlled?
    tournament_monitor.blank? || tournament_monitor.tournament.blank? || tournament_monitor.tournament.player_controlled?
  end

  def follow_up?
    info = '+++ 10 - table_monitor#follow_up? table_monitor'
    DebugInfo.instance.update(info: info)
    Rails.logger.info info
    left_player_id = data['current_left_player'] ? 'playerb' : 'playera'
    right_player_id = data['current_left_player'] ? 'playera' : 'playerb'
    data.present? &&
      ((data['current_inning'].andand['active_player'] == right_player_id) &&
        (data[left_player_id].andand['balls_goal'].to_i.positive? && (data[left_player_id].andand['result'].to_i >= data[left_player_id].andand['balls_goal'].to_i) ||
          (data['innings_goal'].to_i.positive? && data[left_player_id].andand['innings'].to_i >= data['innings_goal'].to_i))
      )
  end

  def undo
    if playing_game?
      current_role = data['current_inning']['active_player']
      the_other_player = (current_role == 'playera' ? 'playerb' : 'playera')
      if (data[the_other_player]['innings']).positive?
        data[the_other_player]['innings_redo_list'] << data[the_other_player]['innings_list'].pop
        data[the_other_player]['innings'] -= 1
        data[the_other_player]['result'] = data[the_other_player]['innings_list'].sum
        data[the_other_player]['hs'] = data[the_other_player]['innings_list'].max
        data[the_other_player]['gd'] =
          format('%.2f', data[the_other_player]['result'].to_f / data[current_role]['innings'])
        data['current_inning']['active_player'] = the_other_player
      end
      data_will_change!
      save
    else
      @msg = 'Game Finished - no more inputs allowed'
      nil
    end
  rescue StandardError => e
    Tournament.logger.info "#{e}, #{e.backtrace.join("\n")}"
  end

  def save_current_set
    if game.present?
      game_set_result = {
        'Gruppe' => game.group_no,
        'Partie' => game.seqno,

        'Spieler1' => game.game_participations.where(role: 'playera').first.player.andand.ba_id,
        'Spieler2' => game.game_participations.where(role: 'playerb').first.player.andand.ba_id,
        'Innings1' => data['playera']['innings_list'].dup,
        'Innings2' => data['playerb']['innings_list'].dup,
        'Ergebnis1' => data['playera']['result'].to_i,
        'Ergebnis2' => data['playerb']['result'].to_i,
        'Aufnahmen1' => data['playera']['innings'].to_i,
        'Aufnahmen2' => data['playerb']['innings'].to_i,
        'Höchstserie1' => data['playera']['hs'].to_i,
        'Höchstserie2' => data['playerb']['hs'].to_i,
        'Tischnummer' => game.table_no
      }
      ba_results = data["ba_results"] ||
        {
          'Gruppe' => game.group_no,
          'Partie' => game.seqno,

          'Spieler1' => game.game_participations.where(role: 'playera').first.player.andand.ba_id,
          'Spieler2' => game.game_participations.where(role: 'playerb').first.player.andand.ba_id,
          'Sets1' => 0,
          'Sets2' => 0,
          'Ergebnis1' => 0,
          'Ergebnis2' => 0,
          'Aufnahmen1' => 0,
          'Aufnahmen2' => 0,
          'Höchstserie1' => 0,
          'Höchstserie2' => 0,
          'Tischnummer' => game.table_no
        }
      ba_results['Sets1'] += 1 if game_set_result['Ergebnis1'] > game_set_result['Ergebnis2']
      ba_results['Sets2'] += 1 if game_set_result['Ergebnis1'] < game_set_result['Ergebnis2']
      ba_results['Ergebnis1'] += game_set_result['Ergebnis1']
      ba_results['Ergebnis2'] += game_set_result['Ergebnis2']
      ba_results['Aufnahmen1'] += game_set_result['Aufnahmen1']
      ba_results['Aufnahmen2'] += game_set_result['Aufnahmen2']
      ba_results['Höchstserie1'] = [ba_results['Höchstserie1'], game_set_result['Höchstserie1']].max
      ba_results['Höchstserie2'] = [ba_results['Höchstserie2'], game_set_result['Höchstserie2']].max

      sets = Array(data["sets"]).push(game_set_result)
      deep_merge_data!('sets' => sets)
      deep_merge_data!('ba_results' => ba_results)

    else
      Rails.logger.info '[prepare_final_game_result] ignored - no game'
    end
  end

  def get_max_number_of_wins
    [data['ba_results'].andand['Sets1'].to_i, data['ba_results'].andand['Sets2'].to_i].max
  end

  def switch_to_next_set
    kickoff_switches_with_set = data['kickoff_switches_with_set']
    current_kickoff_player = data['current_kickoff_player']
    current_kickoff_player = kickoff_switches_with_set ? ((current_kickoff_player == "playera") ? "playerb" : "playera") : current_kickoff_player
    options = {
      'Gruppe' => game.group_no,
      'Partie' => game.seqno,

      'Spieler1' => game.game_participations.where(role: 'playera').first.player.andand.ba_id,
      'Spieler2' => game.game_participations.where(role: 'playerb').first.player.andand.ba_id,
      'Ergebnis1' => 0,
      'Ergebnis2' => 0,
      'Aufnahmen1' => 0,
      'Aufnahmen2' => 0,
      'Höchstserie1' => 0,
      'Höchstserie2' => 0,
      'Tischnummer' => game.table_no,
      'current_kickoff_player' => current_kickoff_player,
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
      'current_inning' => {
        'active_player' => current_kickoff_player,
        'balls' => 0
      }
    }

    deep_merge_data!(options)
    update(state: 'playing_game')
  end

  def evaluate_result
    if (playing_game? || game_show_result? || game_finished? || game_result_reported?) && end_of_set?
      if playing_game?
        event_game_show_result!
        save!
        return
      elsif game_show_result?
        if data["sets_to_play"].to_i > 1
          save_current_set
          max_number_of_wins = get_max_number_of_wins
          if data["sets_to_win"].to_i > 1 && max_number_of_wins < data["sets_to_win"].to_i
            switch_to_next_set
            return
          else
            event_set_result_accepted!
          end
        else
          event_set_result_accepted!
        end
      elsif game_finished?
        # Tournament.logger.info "[table_monitor#evaluate_result] #{caller[0..4].select{|s| s.include?("/app/").join("\n")}"
        event_game_result_reported!
      elsif tournament_monitor.blank? && game.present?
        revert_players
        update(state: 'playing_game')
        do_play
        return
      end
      save!
      reload
      prepare_final_game_result
      tournament_monitor.andand.report_result(self)
    end
  end

  def start_game(options = {})
    @game = game
    if @game.blank?
      @game = Game.create!(table_monitor: self)
    else
      @game.game_participations.destroy_all
    end
    reload
    @game.update(data: {})
    return false if options['player_a_id'].to_i.positive? && options['player_a_id'] == options['player_b_id']

    @game.game_participations.create!(
      player: (options['player_a_id'].to_i.positive? ? Player.find(options['player_a_id']) : nil), role: 'playera'
    )
    @game.game_participations.create!(
      player: (options['player_b_id'].to_i.positive? ? Player.find(options['player_b_id']) : nil), role: 'playerb'
    )
    kickoff_switches_with_set = options['kickoff_switches_with_set']
    color_remains_with_set = options['color_remains_with_set']
    fixed_display_left = options['fixed_display_left'].to_s
    result = {
      'timeouts' => options['timeouts'].to_i,
      'timeout' => options['timeout'].to_i,
      'sets_to_play' => options['sets_to_play'].to_i,
      'sets_to_win' => options['sets_to_win'].to_i,
      'kickoff_switches_with_set' => kickoff_switches_with_set,
      'allow_follow_up' => options['allow_follow_up'],
      'color_remains_with_set' => color_remains_with_set,
      'allow_overflow' => options['allow_overflow'],
      'fixed_display_left' => fixed_display_left,
      'current_kickoff_player' => "playera",
      'current_left_player' => fixed_display_left.present? ? fixed_display_left : "playera",
      'current_left_color' => fixed_display_left == "playerb" ? "yellow" : "white",
      'innings_goal' => options['innings_goal'],
      'playera' => {
        'balls_goal' => options['balls_goal_a'],
        'tc' => options['timeouts'].to_i,
        'discipline' => options['discipline_a'],
        "result" => 0,
        "innings" => 0,
        "innings_list" => [],
        "innings_redo_list" => [],
        "hs" => 0,
        "gd" => "0.00"
      },
      'playerb' => {
        'balls_goal' => options['balls_goal_b'],
        'tc' => options['timeouts'].to_i,
        'discipline' => options['discipline_b'],
        "result" => 0,
        "innings" => 0,
        "innings_list" => [],
        "innings_redo_list" => [],
        "hs" => 0,
        "gd" => "0.00"
      },
    }
    initialize_game
    deep_merge_data!(result)
    true
  end

  def revert_players
    fixed_display_left = data['fixed_display_left']
    options = {
      'player_a_id' => game.game_participations.where(role: 'playerb').first.andand.player.andand.id,
      'player_b_id' => game.game_participations.where(role: 'playera').first.andand.player.andand.id,
      'timeouts' => data['timeouts'].to_i,
      'timeout' => data['timeout'].to_i,
      'innings_goal' => data['innings_goal'].to_i,
      'balls_goal_a' => data['playerb']['balls_goal'].to_i,
      'balls_goal_b' => data['playera']['balls_goal'].to_i,
      'discipline_a' => data['playerb']['discipline'],
      'discipline_b' => data['playera']['discipline'],
      'sets_to_play' => data['sets_to_play'].to_i,
      'sets_to_win' => data['sets_to_win'].to_i,
      'kickoff_switches_with_set' => data['kickoff_switches_with_set'],
      'allow_follow_up' => data['allow_follow_up'],
      'color_remains_with_set' => data['color_remains_with_set'],
      'allow_overflow' => data['allow_overflow'],
      'fixed_display_left' => data['fixed_display_left'],
      'current_kickoff_player' => "playera",
      'current_left_player' => fixed_display_left.present? ? fixed_display_left : "playera",
      'current_left_color' => fixed_display_left == "playerb" ? "yellow" : "white",
    }
    update(game_id: nil)
    start_game(options)
  end

  def set_player_sequence(players)
    (a..d).each_with_index do |ab_seqno, ix|
      next if ix >= players.count

      data['player_map']["player#{ab_seqno}"] = players[ix]
    end
  end

  def end_of_set?
    if data['playera']['balls_goal'].to_i.positive? && ((data['playera']['result'].to_i >= data['playera']['balls_goal'].to_i ||
      data['playerb']['result'].to_i >= data['playerb']['balls_goal'].to_i) &&
      (data['playera']['innings'] == data['playerb']['innings'] || !data["allow_follow_up"]))
      return true
    elsif ((data['innings_goal'].to_i.positive? && data['playera']['innings'].to_i >= data['innings_goal'].to_i) ||
      (data['innings_goal'].to_i.positive? && data['playera']['innings'].to_i >= data['innings_goal'].to_i)) &&
      (data['playera']['innings'] == data['playerb']['innings'] || !data["allow_follow_up"])
      return true
    end

    false
  end

  def name
    table.andand.name
  end

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    data_will_change!
    self.data = JSON.parse(h.to_json)
    save!
  end

  def deep_delete!(key, do_save = true)
    h = data.dup
    res = nil
    if h[key].present?
      res = h.delete(key)
      data_will_change!
      self.data = JSON.parse(h.to_json)
      save! if do_save
    end
    res
  end

  def prepare_final_game_result
    if game.present?
      game_ba_result = {
        'Gruppe' => game.group_no,
        'Partie' => game.seqno,

        'Spieler1' => game.game_participations.where(role: 'playera').first.player.andand.ba_id,
        'Spieler2' => game.game_participations.where(role: 'playerb').first.player.andand.ba_id,
        'Ergebnis1' => data['playera']['result'].to_i,
        'Ergebnis2' => data['playerb']['result'].to_i,
        'Aufnahmen1' => data['playera']['innings'].to_i,
        'Aufnahmen2' => data['playerb']['innings'].to_i,
        'Höchstserie1' => data['playera']['hs'].to_i,
        'Höchstserie2' => data['playerb']['hs'].to_i,
        'Tischnummer' => game.table_no
      }
      deep_merge_data!('ba_results' => game_ba_result)
      game.andand.deep_merge_data!(data) if tournament_monitor_id.blank? and game_finished?

    else
      Rails.logger.info '[prepare_final_game_result] ignored - no game'
    end
  end

  def reset_table_monitor
    if tournament_monitor.present? && !tournament_monitor.tournament.manual_assignment?
      info = '+++ 8 - IGNORING table_monitor#reset_table_monitor - cannot reset managed tournament'
      DebugInfo.instance.update(info: info); Rails.logger.info info
    else
      info = '+++ 8 - table_monitor#reset_table_monitor'
      DebugInfo.instance.update(info: info); Rails.logger.info info
      force_we_re_ready! unless new_record?
      save!
      update(tournament_monitor_id: nil, game_id: nil, nnn: nil, panel_state: 'pointer_mode', data: {})
    end
  rescue StandardError => e
    e
  end
end
