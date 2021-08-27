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
#  game_id               :integer
#  next_game_id          :integer
#  table_id              :integer          not null
#  timer_job_id          :string
#  tournament_monitor_id :integer
#
class TableMonitor < ApplicationRecord
  include CableReady::Broadcaster

  cattr_accessor :allow_change_tables

  include AASM
  belongs_to :tournament_monitor, optional: true
  belongs_to :game, optional: true
  belongs_to :table
  has_paper_trail

  before_create :on_create
  before_save :log_state_change

  delegate :name, to: :table, allow_nil: true

  DEFAULT_ENTRY = {
    "inputs" => "numbers",
    "pointer_mode" => "pointer_mode",
    "shootout" => "start_game",
    "timer" => "play", #depends on state !
    "setup" => "continue",
    "numbers" => "number_field",
    "game_finished" => "game_state",
    "game_show_result" => "game_state",
    "game_result_reported" => "game_state",
    "ready_for_new_game" => "game_state",
    "show_results" => "game_state",
    "warning" => "ok"
  }
  NNN = "db" #store nnn in database table_monitor

  def log_state_change
    if state_changed?
      Rails.logger.info "[TableMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}"
    end
  end

  serialize :data, Hash

  #todo I18n

  aasm :column => 'state' do
    state :new_table_monitor, initial: true, :after_enter => [:reset_table_monitor]
    state :ready
    state :game_setup_started
    state :game_warmup_a_started
    state :game_warmup_b_started
    state :game_shootout_started
    state :playing_game, :after_enter => [:set_start_time], :after_exit => [:set_end_time]
    state :game_show_result, :after_enter => [:set_game_show_result_panel_state]
    state :game_finished, :after_enter => [:set_game_show_result_panel_state]
    state :game_result_reported, :after_enter => [:set_game_show_result_panel_state]
    state :ready_for_new_game #previous game result still displayed here - and probably next players
    event :start_new_game do
      transitions from: [:ready, :ready_for_new_game, :game_setup_started, :game_result_reported, :game_finished], to: :game_setup_started, :after_enter => [:initialize_game]
    end
    event :result_accepted do
      transitions from: [:playing_game, :game_result_reported, :ready_for_new_game], to: :ready_for_new_game
    end
    event :event_play_warm_up_a do
      transitions from: [:game_setup_started, :game_warmup_b_started, :game_warmup_a_started], to: :game_warmup_a_started
    end
    event :event_play_warm_up_b do
      transitions from: [:game_setup_started, :game_warmup_a_started, :game_warmup_b_started], to: :game_warmup_b_started
    end
    event :event_warmup_finished do
      transitions from: [:game_shootout_started, :game_setup_started, :game_warmup_a_started, :game_warmup_b_started], to: :game_shootout_started
    end
    event :event_shootout_finished do
      transitions from: :game_shootout_started, to: :playing_game
    end
    event :event_game_show_result do
      transitions from: :playing_game, to: :game_show_result
    end
    event :event_game_result_accepted do
      transitions from: :game_show_result, to: :game_finished
    end
    event :event_game_result_reported do
      transitions from: [:game_result_reported, :game_finished], to: :game_result_reported
    end
    event :we_re_ready do
      transitions from: [:new_table_monitor, :game_result_reported], to: :ready
    end
    event :force_we_re_ready do
      transitions to: :ready
    end
  end

  def on_create
    info = "+++ 8xxx - table_monitor#on_create"; DebugInfo.instance.update(info: info); Rails.logger.info info
  end

  def state_display(locale)
    @locale = locale || I18n.default_locale
    I18n.t("table_monitor.status.#{state}")
  end

  def log_state_change
    if state_changed?
      Tournament.logger.info "[TableMonitor] STATE_CHANGED [#{id}]: #{state_change[0]} -> #{state_change[1]}"
    end
  end

  def set_game_show_result_panel_state
    update(panel_state: "game_finished", current_element: "game_state")
  end

  after_commit do
    if previous_changes.present?
      Rails.logger.warn "+++ after_commit table_monitor[#{id}] #{previous_changes.inspect}"
      self.reload.evaluate_panel_and_current
      if changes.present?
        Rails.logger.warn "+++ after_commit evaluate_panel_and_current table_monitor[#{id}] #{changes.inspect}"
        save
      else
        #TableMonitorLaterJob.perform_later(self)
        full_screen_html = ApplicationController.render(
          partial: "table_monitors/show",
          locals: { table_monitor: self, full_screen: true }
        )
        cable_ready["table-monitor-stream"].inner_html(
          selector: "#full_screen_table_monitor_#{id}",
          html: full_screen_html
        )
        cable_ready.broadcast
      end
    end
  end

  def numbers
    active_player = data["current_inning"].andand["active_player"]
    nnn_val = data[active_player].andand["innings_redo_list"].andand[-1].to_i
    self.update(nnn: nnn_val)
    full_screen_html = ApplicationController.render(
      partial: "table_monitors/show",
      locals: { table_monitor: self, full_screen: true }
    )
    cable_ready["table-monitor-stream"].inner_html(
      selector: "#full_screen_table_monitor_#{id}",
      html: full_screen_html
    )
    cable_ready.broadcast
  end

  def update_every_n_seconds(n)
    TableMonitorJob.perform_later(self, n, self.data["current_inning"]["active_player"], self.data[self.data["current_inning"]["active_player"]]["innings_redo_list"][-1].to_i, self.data[self.data["current_inning"]["active_player"]]["innings"])
  end

  def player_a_has_played_on_table_before
    false
  end

  def player_b_has_played_on_table_before
    false
  end

  def do_play
    return unless tournament_monitor_id.present? || data["timeout"].to_i > 0
    active_timer = "timeout"
    units = "seconds"
    start_at = Time.now
    finish_at = Time.now + (tournament_monitor.andand.tournament.andand.send(active_timer.to_sym).andand.send(units.to_sym) || (data["timeout"].to_i > 0 ? data["timeout"].to_i.seconds : 5.minutes)).to_i
    if timer_halt_at.present?
      extend = Time.now - timer_halt_at
      start_at = timer_start_at + extend
      finish_at = timer_finish_at + extend
    end
    update(
      active_timer: active_timer,
      timer_halt_at: nil,
      timer_start_at: start_at,
      timer_finish_at: finish_at)
    update_every_n_seconds(2);
  end

  def render_innings_list(role)
    innings = data["playera"]["innings"].to_i
    cols = [(innings/15.0).ceil, 2].max
    show_innings = Array(data[role].andand["innings_list"])
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
    (1..cols).each do |icol|
      ret << "<th>Aufn</th><th>Pkt</th><th>∑</th>"
    end
    ret << "</tr></thead><tbody>"
    sum = 0
    sums = []
    show_innings.each_with_index do |inning, ix|
      sum += inning
      sums[ix] = sum
    end
    (0..14).each do |ix|
      ret << "<tr>"
      (1..cols).each_with_index do |col, icol|
        ret << "<td><span class=\"sm:text-xs lg:text-lg sm:px-2 lg:px-4\">#{ix + 1 + (icol*15)}</span></td>
<td><span class=\"sm:text-xs lg:text-lg sm:px-2 lg:px-4\">#{(ix + (icol*15)) == sums.length ? "GD" : show_innings[ix + (icol*15)]}</span></td>
<td><span class=\"sm:text-xs lg:text-lg sm:px-2 lg:px-4\">#{(ix + (icol*15)) == sums.length ? "%0.2f" % (sums.last.to_i / innings.to_f) : (ix + (icol*15)) == sums.length - 1 ? "<strong class=\"text-3vw\">#{sums[ix + (icol*15)]}</strong>" : sums[ix + (icol*15)]}</span></td>"
      end
      ret << "</tr>"
    end
    ret << "</tbody></table>"
    ret.join("\n").html_safe
  end

  def render_last_innings(n, role)
    show_innings = Array(data[role].andand["innings_list"])
    ret = show_innings.dup
    Array(data[role].andand["innings_redo_list"]).reverse.each_with_index do |i, ix|
      ret << "#{ix == 0 ? "<strong class=\"border-2 border-green-600 p-1\">#{i}</strong>" : "#{i}"}"
    end
    return ret.length > n ?
             ("..." + ret[-n..-1].join("-")).html_safe :
             ret.join("-").html_safe
  end

  def setup_modal_should_be_open?
    game_setup_started? || game_warmup_a_started? || game_warmup_b_started?
  end

  def shootout_modal_should_be_open?
    game_shootout_started?
  end

  def numbers_modal_should_be_open?
    self.nnn.present? || self.panel_state == "numbers"
  end

  def get_progress_bar_status(n)
    time_counter = green_bars = 0
    finish = timer_finish_at
    start = timer_start_at
    if (finish.present? && timer_halt_at.present?)
      halted = Time.now - timer_halt_at
      finish = finish + halted
      start = start + halted
    end
    if (finish.present? && (Time.now < finish))
      delta_total = (finish - start).to_i
      delta_rest = (finish - Time.now)
      units = active_timer =~ /min$/ ? "minutes" : "seconds"
      if (units == "minutes")
        minutes = (delta_rest / 1.send(units)).to_i
        seconds = ((((delta_rest / 1.send(units)) - (delta_rest.to_i / 1.send(units))) * 100 * 60 / 100).to_i + 100).to_s[-2..-1]
        time_counter = "#{minutes}:#{seconds}"
      else
        time_counter = (1.0 * delta_rest / 1.send(units)).ceil
      end
      green_bars = [((1.0 * n * delta_rest) / delta_total).ceil, 18].min
    end
    return [time_counter, green_bars]
  end

  def switch_players
    if game.present?
      roles = game.game_participations.map(&:role).reverse
      game.game_participations.each_with_index do |gp, ix|
        gp.update(role: roles[ix])
      end
      ret_a = data["playerb"].dup
      ret_b = data["playera"].dup
      deep_merge_data!({
                         "playera" => ret_a,
                         "playerb" => ret_b,
                       })
    end
  end

  def switch_colors
    deep_merge_data!({
                       switch_colors: !data[:switch_colors].present?,
                     })
  end

  def set_start_time
    game.update(started_at: Time.now)
  end

  def set_end_time
    game.update(ended_at: Time.now)
  end

  def assign_game(game_p)
    info = "+++ 8c - tournament_monitor#assign_game - game_p"; DebugInfo.instance.update(info: info); Rails.logger.info info
    info = "+++ 8d - tournament_monitor#assign_game - table_monitor"; DebugInfo.instance.update(info: info); Rails.logger.info info
    self.allow_change_tables = tournament_monitor.andand.allow_change_tables
    tmp_results = game_p.deep_delete!("tmp_results")
    if tmp_results.andand["state"].present?
      info = "+++ 8e - tournament_monitor#assign_game - table_monitor"; DebugInfo.instance.update(info: info); Rails.logger.info info
      state = tmp_results.delete("state")
      deep_merge_data!(tmp_results)
      update(game_id: game_p.id, state: state)
    else
      update(game_id: game_p.id, state: "ready")
      reload
      info = "+++ 8f - tournament_monitor#assign_game - table_monitor"; DebugInfo.instance.update(info: info); Rails.logger.info info
      initialize_game
      save!
      if [:ready, :ready_for_new_game, :game_setup_started, :game_result_reported, :game_finished].include?(self.state.to_sym)
        info = "+++ 8g - tournament_monitor#assign_game - start_new_game"; DebugInfo.instance.update(info: info); Rails.logger.info info
        start_new_game!
      end
    end
  end

  def initialize_game
    info = "+++ 7 - table_monitor#initialize_game"; DebugInfo.instance.update(info: info); Rails.logger.info info
    deep_merge_data! ({

      "innings_goal" =>
        tournament_monitor.andand.innings_goal ||
          tournament_monitor.andand.tournament.andand.innings_goal,
      "playera" => {
        "result" => 0,
        "innings" => 0,
        "innings_list" => [],
        "innings_redo_list" => [],
        "hs" => 0,
        "gd" => 0.0,
        "balls_goal" =>
          data["result"].andand["playera"].andand["balls_goal"] ||
            tournament_monitor.andand.tournament.andand.handicap_tournier? && seeding_from("playera").balls_goal.presence ||
            tournament_monitor.andand.balls_goal ||
            tournament_monitor.andand.tournament.andand.balls_goal,
        "tc" =>
          tournament_monitor.andand.timeouts ||
            tournament_monitor.andand.tournament.andand.timeouts ||
            0,
      },
      "playerb" => {
        "result" => 0,
        "innings" => 0,
        "innings_list" => [],
        "innings_redo_list" => [],
        "hs" => 0,
        "gd" => 0.0,
        "balls_goal" =>
          data["result"].andand["playerb"].andand["balls_goal"] ||
            tournament_monitor.andand.tournament.andand.handicap_tournier? && seeding_from("playerb").balls_goal.presence ||
            tournament_monitor.andand.balls_goal ||
            tournament_monitor.andand.tournament.andand.balls_goal,
        "tc" =>
          tournament_monitor.andand.timeouts ||
            tournament_monitor.andand.tournament.andand.timeouts ||
            0,
      },
      "current_inning" => {
        "active_player" => "playera",
        "balls" => 0
      }
    })
    # self.panel_state = "pointer_mode"
    # self.current_element = "pointer_mode"
    data
  end

  def display_name
    t_no = (name || table.name).andand.match(/.*(\d+)/).andand[1]
    I18n.t("table_monitors.display_name", t_no: t_no)
  end

  def seeding_from(role)
    #TODO - puh can't this be easiere?
    game.game_participations.where(role: role).first.
      player.seedings.where("seedings.id >= #{Seeding::MIN_ID}").where(tournament_id: tournament_monitor.tournament_id).first
  end

  def add_n_balls_to_current_players_inning(n)
    begin
      @msg = nil
      if playing_game?
        current_role = data["current_inning"]["active_player"]
        data[current_role]["innings_redo_list"] = [0] if data[current_role]["innings_redo_list"].empty?
        to_play = data[current_role].andand["balls_goal"].to_i <= 0 ? 99999 : data[current_role].andand["balls_goal"].to_i - (data[current_role].andand["result"].to_i + data[current_role]["innings_redo_list"][-1].to_i)
        add = [n, to_play].min
        data[current_role]["innings_redo_list"][-1] = [(data[current_role]["innings_redo_list"][-1].to_i + add), 0].max
        if add == to_play
          data_will_change!
          save
          terminate_current_inning
        else
          #data[current_role]["innings_redo_list"].pop if Array(data[current_role]["innings_redo_list"]).last.to_i > 10000
          data_will_change!
        end
        # update(
        #   panel_state: "pointer_mode",
        #   current_element: "pointer_mode")
      else
        @msg = "Game Finished - no more inputs allowed"
        return nil
      end
    rescue Exception => e
      Tournament.logger.info "#{e}, #{e.backtrace.join("\n")}"
    end
  end

  def reset_timer!
    begin
      assign_attributes(
        active_timer: nil,
        timer_start_at: nil,
        timer_finish_at: nil,
        timer_halt_at: nil
      )
    rescue Exception => e
      Tournament.logger.info "#{e}, #{e.backtrace.join("\n")}"
    end
  end

  def msg
    @msg
  end

  def evaluate_panel_and_current
    element_to_panel_state = {
      "undo" => "inputs",
      "minus_one" => "inputs",
      "minus_ten" => "inputs",
      "next_step" => "inputs",
      "add_ten" => "inputs",
      "add_one" => "inputs",
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
      "practice_b" => "setup",
    }
    new_current_element = new_panel_state = nil
    if setup_modal_should_be_open?
      new_panel_state = "setup"
    elsif self.shootout_modal_should_be_open?
      new_panel_state = "shootout"
    elsif self.numbers_modal_should_be_open?
      new_panel_state = "numbers"
    elsif self.game_show_result? || self.game_finished?
      new_panel_state = "show_results"
    else
      #new_panel_state = "pointer_mode"
    end
    if new_panel_state.present?
      new_current_element = TableMonitor::DEFAULT_ENTRY[new_panel_state]
      if new_panel_state == "timer"
        new_current_element = (timer_finish_at.present? && self.timer_halt_at.blank?) ? "pause" : "play"
      end
    else
      new_panel_state = self.panel_state
      new_current_element = self.current_element
    end
    self.assign_attributes(panel_state: new_panel_state, current_element: element_to_panel_state[new_current_element] == new_panel_state ? new_current_element : TableMonitor::DEFAULT_ENTRY[self.panel_state])
  end

  def set_n_balls_to_current_players_inning(n_balls, change_to_pointer_mode = false)
    @msg = nil
    if playing_game?
      current_role = data["current_inning"]["active_player"]
      data[current_role]["innings_redo_list"] = [0] if data[current_role]["innings_redo_list"].empty?
      to_play = data[current_role].andand["balls_goal"].to_i <= 0 ? 99999 : data[current_role].andand["balls_goal"].to_i - (data[current_role].andand["result"].to_i)
      set = [n_balls.to_i, to_play.to_i].min
      data[current_role]["innings_redo_list"][-1] = set
      data_will_change!
      assign_attributes(nnn: nil, panel_state: change_to_pointer_mode ? "pointer_mode" : self.panel_state)
      if set == to_play
        terminate_current_inning
      end
    else
      @msg = "Game Finished - no more inputs allowed"
      return nil
    end
  end

  def terminate_current_inning
    begin
      @msg = nil
      current_role = data["current_inning"]["active_player"]
        if playing_game? && (data["innings_goal"].to_i == 0 || data[current_role]["innings"].to_i < data["innings_goal"].to_i)
        n_balls = Array(data[current_role]["innings_redo_list"]).pop.to_i
        data[current_role]["innings_list"] ||= []
        data[current_role]["innings_redo_list"] ||= []
        data[current_role]["innings_list"] << n_balls
        data[current_role]["result"] = data[current_role]["innings_list"].sum
        data[current_role]["innings"] += 1 if data["innings_goal"].to_i == 0 || data[current_role]["innings"].to_i < data["innings_goal"].to_i
        data[current_role]["hs"] = n_balls if n_balls > data[current_role]["hs"].to_i
        data[current_role]["gd"] = sprintf("%.2f", data[current_role]["result"].to_f / data[current_role]["innings"])
        other_player = current_role == "playera" ? "playerb" : "playera"
        data["current_inning"]["active_player"] = other_player
        data[other_player]["innings_redo_list"] = [0] if data[current_role]["innings_redo_list"].empty?
        data_will_change!
        save
        if data["current_inning"]["active_player"] == "playera"
          evaluate_result
        end
      else
        @msg = "Game Finished - no more inputs allowed"
        return nil
      end
    rescue Exception => e
      Tournament.logger.info "#{e}, #{e.backtrace.join("\n")}"
    end
  end

  def follow_up?
    info = "+++ 10 - table_monitor#follow_up? table_monitor"
    DebugInfo.instance.update(info: info)
    Rails.logger.info info
    data.present? &&
      ((data["current_inning"].andand["active_player"] == "playerb") && data["playera"].andand["balls_goal"].to_i > 0 && (data["playera"].andand["result"].to_i >= data["playera"].andand["balls_goal"].to_i))
  end

  def undo
    begin
      if playing_game?
        current_role = data["current_inning"]["active_player"]
        the_other_player = (current_role == "playera" ? "playerb" : "playera")
        if data[the_other_player]["innings"] > 0
          data[the_other_player]["innings_redo_list"] << data[the_other_player]["innings_list"].pop
          data[the_other_player]["innings"] -= 1
          data[the_other_player]["result"] = data[the_other_player]["innings_list"].sum
          data[the_other_player]["hs"] = data[the_other_player]["innings_list"].max
          data[the_other_player]["gd"] = sprintf("%.2f", data[the_other_player]["result"].to_f / data[current_role]["innings"])
          data["current_inning"]["active_player"] = the_other_player
        end
        data_will_change!
        save
      else
        @msg = "Game Finished - no more inputs allowed"
        return nil
      end
    rescue Exception => e
      Tournament.logger.info "#{e}, #{e.backtrace.join("\n")}"
    end
  end

  def evaluate_result
    if playing_game? || game_show_result? || game_finished? || game_result_reported?
      if end_result?
        if playing_game?
          event_game_show_result!
          save!
          return
        elsif game_show_result?
          event_game_result_accepted!
        elsif game_finished?
          event_game_result_reported!
        else
          if tournament_monitor.blank? && game.present?
            revert_players
            update(state: "playing_game")
            do_play
            return
          end
        end
        save!
        reload
        prepare_final_game_result
        tournament_monitor.andand.report_result(self)
      end
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
      if (options["player_a_id"].to_i > 0 && options["player_a_id"] == options["player_b_id"])
        return false
      end
      @game.game_participations.create!(player: (options["player_a_id"].to_i > 0 ? Player.find(options["player_a_id"]) : nil), role: "playera")
      @game.game_participations.create!(player: (options["player_b_id"].to_i > 0 ? Player.find(options["player_b_id"]) : nil), role: "playerb")

      result = {
        "timeouts" => options["timeouts"].to_i,
        "timeout" => options["timeout"].to_i,
        "innings_goal" => options["innings_goal"],
        "playera" => {
          "balls_goal" => options["balls_goal_a"],
          "tc" => options["timeouts"].to_i,
          "discipline" => options["discipline_a"],
        },
        "playerb" => {
          "balls_goal" => options["balls_goal_b"],
          "tc" => options["timeouts"].to_i,
          "discipline" => options["discipline_b"],
        },
      }
      initialize_game
      deep_merge_data!(result)
      return true
  end

  def revert_players
    options = {
      "player_a_id" => game.game_participations.where(role: "playerb").first.andand.player.andand.id,
      "player_b_id" => game.game_participations.where(role: "playera").first.andand.player.andand.id,
      "timeouts" => data["timeouts"].to_i,
      "timeout" => data["timeout"].to_i,
      "innings_goal" => data["innings_goal"].to_i,
      "balls_goal_a" => data["playerb"]["balls_goal"].to_i,
      "balls_goal_b" => data["playera"]["balls_goal"].to_i,
      "discipline_a" => data["playerb"]["discipline"],
      "discipline_b" => data["playera"]["discipline"]
    }
    update(game_id: nil)
    start_game(options)
  end

  def set_player_sequence(players)
    (a..d).each_with_index do |ab_seqno, ix|
      next if ix >= players.count
      data["player_map"]["player#{ab_seqno}"] = players[ix]
    end
  end

  def end_result?
    if data["playera"]["balls_goal"].to_i > 0 && ((data["playera"]["result"].to_i >= data["playera"]["balls_goal"].to_i ||
      data["playerb"]["result"].to_i >= data["playerb"]["balls_goal"].to_i) &&
      data["playera"]["innings"] == data["playerb"]["innings"])
      return true
    elsif ((data["innings_goal"].to_i > 0 && data["playera"]["innings"].to_i >= data["innings_goal"].to_i) ||
      (data["innings_goal"].to_i > 0 && data["playera"]["innings"].to_i >= data["innings_goal"].to_i)) &&
      data["playera"]["innings"] == data["playerb"]["innings"]
      return true
    end
    return false
  end

  def name
    table.andand.name
  end

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    self.data_will_change!
    self.data = JSON.parse(h.to_json)
    save!
  end

  def deep_delete!(key, do_save = true)
    h = data.dup
    res = nil
    if h[key].present?
      res = h.delete(key)
      self.data_will_change!
      self.data = JSON.parse(h.to_json)
      save! if do_save
    end
    res
  end

  def prepare_final_game_result
    if game.present?
      game_ba_result = {
        "Gruppe" => game.group_no,
        "Partie" => game.seqno,

        "Spieler1" => game.game_participations.where(role: "playera").first.player.ba_id,
        "Spieler2" => game.game_participations.where(role: "playerb").first.player.ba_id,
        "Ergebnis1" => data["playera"]["result"].to_i,
        "Ergebnis2" => data["playerb"]["result"].to_i,
        "Aufnahmen1" => data["playera"]["innings"].to_i,
        "Aufnahmen2" => data["playerb"]["innings"].to_i,
        "Höchstserie1" => data["playera"]["hs"].to_i,
        "Höchstserie2" => data["playerb"]["hs"].to_i,
        "Tischnummer" => game.table_no
      }
      deep_merge_data!("ba_results" => game_ba_result)
    else
      Rails.logger.info "[prepare_final_game_result] ignored - no game"
    end
  end

  def reset_table_monitor
    info = "+++ 8 - table_monitor#reset_table_monitor"; DebugInfo.instance.update(info: info); Rails.logger.info info
    force_we_re_ready!
    save!
    update(game_id: nil, nnn: nil, panel_state: "pointer_mode", data: {})
  end
end
