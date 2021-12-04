# frozen_string_literal: true

class TableMonitorReflex < ApplicationReflex
  # Add Reflex methods in this file.
  #
  # All Reflex instances expose the following properties:
  #
  #   - connection - the ActionCable connection
  #   - channel - the ActionCable channel
  #   - request - an ActionDispatch::Request proxy for the socket connection
  #   - session - the ActionDispatch::Session store for the current visitor
  #   - url - the URL of the page that triggered the reflex
  #   - element - a Hash like object that represents the HTML element that triggered the reflex
  #   - params - parameters from the element's closest form (if any)
  #
  # Example:
  #
  #   def example(argument=true)
  #     # Your logic here...
  #     # Any declared instance variables will be made available to the Rails controller and view.
  #   end
  #
  # Learn more at: https://docs.stimulusreflex.com
  #
  (0..9).each do |i|
    define_method :"nnn_#{i}" do
      key(element.dataset[:id], i)
    end
  end

  def key(table_monitor_id, val)
    morph :nothing
    if TableMonitor::NNN == 'db'
      table_monitor_id = element.andand.dataset[:id]
      @table_monitor = TableMonitor.find(table_monitor_id)
      @table_monitor.update(nnn: val == 'c' ? @table_monitor.nnn.to_i / 10 : (@table_monitor.nnn || 0) * 10 + val)
      # cable_ready["table-monitor-stream"].inner_html(
      #   selector: "#number_field",
      #   html: @table_monitor.nnn.to_s
      # )
      # cable_ready.broadcast
    else
      session_key = :"nnn_#{table_monitor_id}"
      session[session_key] = val == 'c' ? 0 : (session[session_key] || 0) * 10 + val
      cable_ready['table-monitor-stream'].inner_html(
        selector: '#number_field',
        html: session[session_key].to_s
      )
      cable_ready.broadcast
    end
  end

  def nnn_del
    key(element.andand.dataset[:id], 'c')
  end

  def nnn_enter
    morph :nothing
    table_monitor_id = element.andand.dataset[:id]
    @table_monitor = TableMonitor.find(table_monitor_id)
    @table_monitor.reset_timer!

    if TableMonitor::NNN == 'db'
      @table_monitor.set_n_balls(@table_monitor.nnn, true)
    else
      session_key = :"nnn_#{table_monitor_id}"
      @table_monitor.set_n_balls(session[session_key].to_i, true)
    end
    @table_monitor.save
  end

  def outside
    morph :nothing
    table_monitor_id = element.andand.dataset[:id]
    @table_monitor = TableMonitor.find(table_monitor_id)
    @table_monitor.touch
    @table_monitor.assign_attributes(nnn: nil, panel_state: 'pointer_mode', current_element: 'pointer_mode')
    @table_monitor.save
  end

  def key_pressed
    morph :nothing
  end

  def key_a
    morph :nothing
    TableMonitor.transaction do
      @table_monitor = TableMonitor.find(element.andand.dataset[:id])
      # noinspection RubyResolve
      if @table_monitor.setup_modal_should_be_open?
        # noinspection RubyResolve
        warmup_state_change('a') if @table_monitor.game_setup_started? || @table_monitor.game_warmup_b_started?
      elsif @table_monitor.shootout_modal_should_be_open?
        @table_monitor.reset_timer!
        @table_monitor.switch_players
      elsif @table_monitor.playing_game?
        case @table_monitor.data['current_inning']['active_player']
        when 'playera'
          @table_monitor.reset_timer!
          @table_monitor.add_n_balls(1)
          @table_monitor.do_play
          @table_monitor.assign_attributes(panel_state: 'pointer_mode', current_element: 'pointer_mode')
        when 'playerb'
          @table_monitor.reset_timer!
          @table_monitor.terminate_current_inning
          @table_monitor.do_play
          @table_monitor.assign_attributes(panel_state: 'pointer_mode', current_element: 'pointer_mode')
        else
          # type code here
        end
      elsif (@table_monitor.game_show_result? && @table_monitor.player_controlled?) || @table_monitor.game_finished?
        @table_monitor.evaluate_result
      end
      @table_monitor.save
    end
  end

  def key_b
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    # noinspection RubyResolve
    if @table_monitor.setup_modal_should_be_open?
      # noinspection RubyResolve
      warmup_state_change('b') if @table_monitor.game_setup_started? || @table_monitor.game_warmup_a_started?
    elsif @table_monitor.shootout_modal_should_be_open?
      @table_monitor.reset_timer!
      @table_monitor.switch_players
    elsif @table_monitor.playing_game?
      case @table_monitor.data['current_inning']['active_player']
      when 'playerb'
        @table_monitor.reset_timer!
        @table_monitor.add_n_balls(1)
        @table_monitor.do_play
        @table_monitor.assign_attributes(panel_state: 'pointer_mode', current_element: 'pointer_mode')
      when 'playera'
        @table_monitor.reset_timer!
        @table_monitor.terminate_current_inning
        @table_monitor.do_play
        @table_monitor.assign_attributes(panel_state: 'pointer_mode', current_element: 'pointer_mode')
      else
        # type code here
      end
    elsif @table_monitor.game_show_result? || @table_monitor.game_result_reported?
      @table_monitor.evaluate_result
      # @table_monitor.event_game_result_accepted!
      # @table_monitor.prepare_final_game_result
    elsif @table_monitor.game_finished?
      if @table_monitor.tournament_monitor.present?
        @table_monitor.evaluate_result
        # @table_monitor.tournament_monitor.report_result(@table_monitor)
      else
        # noinspection RubyResolve
        # Tournament.logger.info "[table_monitor_reflex#keyb] #{caller[0..4].select{|s| s.include?("/app/").join("\n")}"
        @table_monitor.event_game_result_reported!
        @table_monitor.reset_table_monitor
      end
    end
    @table_monitor.save
  end

  def key_c
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    # noinspection RubyResolve
    if @table_monitor.setup_modal_should_be_open?
      # noinspection RubyResolve
      if @table_monitor.game_warmup_a_started? || @table_monitor.game_warmup_b_started?
        # void
      end
    elsif @table_monitor.game_show_result? || @table_monitor.game_result_reported?
      @table_monitor.evaluate_result
      # @table_monitor.event_game_result_accepted!
      # @table_monitor.prepare_final_game_result
    elsif @table_monitor.game_finished?
      @table_monitor.evaluate_result
    end
    @table_monitor.save
  end

  def key_d
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    # noinspection RubyResolve
    if @table_monitor.setup_modal_should_be_open?
      # noinspection RubyResolve
      if @table_monitor.game_setup_started? || @table_monitor.game_warmup_a_started? || @table_monitor.game_warmup_b_started?
        # start shoot-out
        @table_monitor.reset_timer!
        @table_monitor.event_warmup_finished!
      end
    elsif @table_monitor.shootout_modal_should_be_open?
      # start game
      @table_monitor.reset_timer!
      @table_monitor.event_shootout_finished!
      @table_monitor.evaluate_result
      # @table_monitor.do_play
    elsif @table_monitor.playing_game?
      @table_monitor.terminate_current_inning if @table_monitor.end_result?
    elsif @table_monitor.game_show_result? || @table_monitor.game_result_reported?
      @table_monitor.evaluate_result
      # @table_monitor.event_game_result_accepted!
      # @table_monitor.prepare_final_game_result
    elsif @table_monitor.game_finished?
      @table_monitor.evaluate_result
      # @table_monitor.tournament_monitor.report_result(@table_monitor)
    end
    @table_monitor.save
  end

  def undo
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.panel_state = 'inputs'
    @table_monitor.undo
    @table_monitor.save
  end

  def minus_one
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.panel_state = 'inputs'
    @table_monitor.current_element = 'minus_one'
    @table_monitor.reset_timer!
    @table_monitor.add_n_balls(-1)
    @table_monitor.save
  end

  def minus_ten
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.panel_state = 'inputs'
    @table_monitor.current_element = 'minus_ten'
    @table_monitor.reset_timer!
    @table_monitor.add_n_balls(-10)
    @table_monitor.save
  end

  def minus_five
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.panel_state = 'inputs'
    @table_monitor.current_element = 'minus_five'
    @table_monitor.reset_timer!
    @table_monitor.add_n_balls(-5)
    @table_monitor.save
  end

  def switch_players
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.panel_state = 'inputs'
    @table_monitor.switch_players
    @table_monitor.save
  end

  def switch_colors
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.panel_state = 'inputs'
    @table_monitor.switch_colors
    @table_monitor.save
  end

  def start_game
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.reset_timer!
    # noinspection RubyResolve
    @table_monitor.event_shootout_finished!
    @table_monitor.panel_state = 'pointer_mode'
    @table_monitor.do_play
    @table_monitor.save
  end

  def home; end

  def add_one
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.panel_state = 'inputs'
    @table_monitor.current_element = 'add_one'
    @table_monitor.reset_timer!
    Rails.logger.warn("[add_one] ++++A++++ #{JSON.pretty_generate(@table_monitor.attributes.delete_if do |k, _v|
      k == 'data'
    end)}")
    @table_monitor.add_n_balls(1)
    @table_monitor.do_play
    Rails.logger.warn("[add_one] ++++B++++ #{JSON.pretty_generate(@table_monitor.attributes.delete_if do |k, _v|
      k == 'data'
    end)}")
    @table_monitor.save
  rescue StandardError => e
    Rails.logger.info("[add_one] #{e} #{e.backtrace.to_a.join("\n")}")
  end

  def add_ten
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.panel_state = 'inputs'
    @table_monitor.current_element = 'add_ten'
    @table_monitor.reset_timer!
    @table_monitor.add_n_balls(10)
    @table_monitor.do_play
    Rails.logger.info('[add_ten] ++++1++++')
    @table_monitor.save
  rescue StandardError => e
    Rails.logger.info("[add_ten] #{e} #{e.backtrace.to_a.join("\n")}")
  end

  def add_five
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.panel_state = 'inputs'
    @table_monitor.current_element = 'add_five'
    @table_monitor.reset_timer!
    @table_monitor.add_n_balls(5)
    @table_monitor.do_play
    Rails.logger.info('[add_five] ++++1++++')
    @table_monitor.save
  rescue StandardError => e
    Rails.logger.info("[add_five] #{e} #{e.backtrace.to_a.join("\n")}")
  end

  def set_balls
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.panel_state = 'inputs'
    @table_monitor.reset_timer!
    @table_monitor.set_n_balls(element.andand.value.to_i)
    @table_monitor.save
  end

  def numbers
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.reset_timer!
    @table_monitor.numbers
    @table_monitor.save
  end

  def up
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    t_no = @table_monitor.internal_name.match(/table(\d+)/).andand[1].to_i
    switch_to = @table_monitor.tournament_monitor.table_monitors.map do |tm|
      tm.internal_name.match(/table(\d+)/).andand[1].to_i
    end.sort
    ix = switch_to.index(t_no)
    ix2 = ix + switch_to.length
    switch_to += switch_to
    new_t_no = switch_to[ix2 - 1]
    tm1 = @table_monitor
    tm2 = @table_monitor.tournament_monitor.table_monitors.where(name: "table#{new_t_no}").first
    game1 = tm1.game
    Rails.logger.info ";;; game1.id=#{game1.andand.id}, tm1: #{JSON.pretty_generate(tm1.attributes)}"
    game2 = tm2.game
    Rails.logger.info ";;; game2.id=#{game2.andand.id}, tm2: #{JSON.pretty_generate(tm2.attributes)}"
    tm1_data = tm1.data.dup
    tm2_data = tm2.data.dup
    tm1.assign_attributes(game_id: game2.id, data: tm2_data)
    tm2.assign_attributes(game_id: game1.id, data: tm1_data)
    tm1.save
    tm2.save
    @table_monitor.reload
  rescue StandardError => e
    Rails.logger.info ";;; up #{e} #{e.backtrace.to_a.join("\n")}"
  end

  def down
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    t_no = @table_monitor.internal_name.match(/table(\d+)/).andand[1].to_i
    switch_to = @table_monitor.tournament_monitor.table_monitors.map do |tm|
      tm.internal_name.match(/table(\d+)/).andand[1].to_i
    end.sort
    ix = switch_to.index(t_no)
    switch_to += switch_to
    new_t_no = switch_to[ix + 1]
    tm1 = @table_monitor
    tm2 = @table_monitor.tournament_monitor.table_monitors.where(name: "table#{new_t_no}").first
    game1 = tm1.game
    Rails.logger.info ";;; game1.id=#{game1.andand.id}, tm1: #{JSON.pretty_generate(tm1.attributes)}"
    game2 = tm2.game
    Rails.logger.info ";;; game2.id=#{game2.andand.id}, tm2: #{JSON.pretty_generate(tm2.attributes)}"
    tm1_data = tm1.data.dup
    tm2_data = tm2.data.dup
    tm1.assign_attributes(game_id: game2.id, data: tm2_data)
    tm2.assign_attributes(game_id: game1.id, data: tm1_data)
    tm1.save
    tm2.save
    @table_monitor.reload
  rescue StandardError => e
    Rails.logger.info ";;; down #{e} #{e.backtrace.to_a.join("\n")}"
  end

  def next_step
    morph :nothing
    Rails.logger.info "next_step from connection #{connection.connection_identifier}"
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.reset_timer!
    @table_monitor.terminate_current_inning
    @table_monitor.save
  end

  def force_next_state
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    # noinspection RubyResolve
    if %i[game_setup_started game_warmup_a_started game_warmup_b_started].include?(@table_monitor.state.to_sym)
      @table_monitor.reset_timer!
      # noinspection RubyResolve
      @table_monitor.event_warmup_finished!
    elsif [:game_shootout_started].include?(@table_monitor.state.to_sym)
      @table_monitor.reset_timer!
      @table_monitor.event_shootout_finished!
    elsif @table_monitor.game_show_result? || @table_monitor.game_result_reported?
      @table_monitor.evaluate_result
      # @table_monitor.event_game_result_accepted!
      # @table_monitor.prepare_final_game_result
    elsif @table_monitor.game_finished?
      if @table_monitor.tournament_monitor.present?
        @table_monitor.evaluate_result
        # @table_monitor.tournament_monitor.report_result(@table_monitor)
      else
        # noinspection RubyResolve
        # Tournament.logger.info "[table_monitor_reflex#force_next_state] #{caller[0..4].select{|s| s.include?("/app/").join("\n")}"
        @table_monitor.event_game_result_reported!
        @table_monitor.reset_table_monitor
      end
    end
    @table_monitor.save
  end

  def stop
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.reset_timer!
    @table_monitor.save
  end

  def warm_up_finished
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.reset_timer!
    # noinspection RubyResolve
    @table_monitor.event_warmup_finished!
    @table_monitor.save
  end

  def play_warm_up_a
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    warmup_state_change('a')
    @table_monitor.save
  end

  def play_warm_up_b
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    warmup_state_change('b')
    @table_monitor.save
  end

  def play
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.panel_state = 'timer'
    @table_monitor.current_element = 'play'
    @table_monitor.do_play
    @table_monitor.save
  end

  def pause
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.assign_attributes(timer_halt_at: Time.now)
    @table_monitor.save
  end

  def timeout
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    # noinspection RubyResolve
    if @table_monitor.playing_game?
      data = @table_monitor.data
      current_role = data['current_inning']['active_player']
      if data['timeout'].to_i.positive? && data[current_role]['tc'].to_i.positive?
        data[current_role]['tc'] = data[current_role]['tc'].to_i - 1
        units = @table_monitor.active_timer =~ /min$/ ? 'minutes' : 'seconds'
        delta = if @table_monitor.tournament_monitor.present?
                  @table_monitor.tournament_monitor.tournament.send(@table_monitor.active_timer.to_sym).send(units.to_sym)
                else
                  (data['timeout'].to_i.positive? ? data['timeout'].to_i.seconds : 5.minutes)
                end
        @table_monitor.update(
          timer_halt_at: nil,
          timer_finish_at: @table_monitor.timer_finish_at + delta,
          data: data
        )
      end
    end
  rescue StandardError => e
    Rails.logger.info("[add_one] #{e} #{e.backtrace.to_a.join("\n")}")
  end

  private

  def warmup_state_change(player)
    morph :nothing
    other_player = player == 'a' ? 'b' : 'a'
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    active_timer = if @table_monitor.send(:"player_#{player}_on_table_before")
                     'time_out_warm_up_follow_up_min'
                   else
                     'time_out_warm_up_first_min'
                   end
    # noinspection RubyResolve
    if @table_monitor.game_setup_started? || @table_monitor.send(:"game_warmup_#{player}_started?") || @table_monitor.send(:"game_warmup_#{other_player}_started?")
      @table_monitor.send(:"event_play_warm_up_#{player}!")
      units = 'minutes' # active_timer =~ /min$/ ? "minutes" : "seconds"
      start_at = Time.now
      delta = @table_monitor.tournament_monitor.present? ? @table_monitor.tournament_monitor.tournament.send(active_timer.to_sym).send(units.to_sym) : 5.minutes
      finish_at = Time.now + delta
      if @table_monitor.timer_halt_at.present?
        extend = Time.now - @table_monitor.timer_halt_at
        start_at += extend
        finish_at += extend
      end
      @table_monitor.assign_attributes(
        active_timer: active_timer,
        timer_halt_at: nil,
        timer_start_at: start_at,
        timer_finish_at: finish_at
      )
      @table_monitor.update_every_n_seconds(2)
    end
    @table_monitor.save
  end

  def submit; end

  def discipline; end

  def innings; end

  def balls_goal; end

  def player_a_name; end

  def discipline_a; end

  def balls_goal_a; end

  def player_b_name; end

  def discipline_b; end

  def balls_goal_b; end
end
