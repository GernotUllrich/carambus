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
  DEBUG = true
  (0..9).each do |i|
    define_method :"nnn_#{i}" do
      Rails.logger.info "+++++++++++++++++>>> #{"nnn_#{i}"} <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
      key(element.dataset[:id], i)
    end
  end

  def key(table_monitor_id, val)
    if DEBUG
      Rails.logger.info "+++++++++++++++++>>> #{"key(#{table_monitor_id}, #{val})"} <<<++++++++++++++++++++++++++++++++++++++"
    end
    morph :nothing
    if TableMonitor::NNN == "db"
      table_monitor_id = element.andand.dataset[:id]
      @table_monitor = TableMonitor.find(table_monitor_id)
      @table_monitor.update(nnn: if val == "c"
                                   0
                                 else
                                   (val == "bsp" ? @table_monitor.nnn.to_i / 10 : (@table_monitor.nnn || 0) * 10 + val)
                                 end)
      # cable_ready["table-monitor-stream"].inner_html(
      #   selector: "#number_field",
      #   html: @table_monitor.nnn.to_s
      # )
      # cable_ready.broadcast
    else
      session_key = :"nnn_#{table_monitor_id}"
      session[session_key] = val == "c" ? 0 : (session[session_key] || 0) * 10 + val
      cable_ready["table-monitor-stream"].inner_html(
        selector: "#number_field",
        html: session[session_key].to_s
      )
      cable_ready.broadcast
    end
  end

  def nnn_del
    Rails.logger.info "+++++++++++++++++>>> nnn_del <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    key(element.andand.dataset[:id], "c")
  end

  def nnn_bsp
    Rails.logger.info "+++++++++++++++++>>> nnn_del <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    key(element.andand.dataset[:id], "bsp")
  end

  def nnn_enter
    Rails.logger.info "+++++++++++++++++>>> nnn_enter <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    table_monitor_id = element.andand.dataset[:id]
    @table_monitor = TableMonitor.find(table_monitor_id)
    @table_monitor.reset_timer!

    if TableMonitor::NNN == "db"
      @table_monitor.set_n_balls(@table_monitor.nnn, true)
    else
      session_key = :"nnn_#{table_monitor_id}"
      @table_monitor.set_n_balls(session[session_key].to_i, true)
    end
    @table_monitor.save
  end

  def outside
    Rails.logger.info "+++++++++++++++++>>> outside <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    table_monitor_id = element.andand.dataset[:id]
    @table_monitor = TableMonitor.find(table_monitor_id)
    @table_monitor.touch
    @table_monitor.assign_attributes(nnn: nil, panel_state: "pointer_mode", current_element: "pointer_mode")
    @table_monitor.save
  end

  def key_pressed
    Rails.logger.info "+++++++++++++++++>>> key_pressed <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
  end

  def key_a
    Rails.logger.info "+++++++++++++++++>>> key_a <<<++++++++++++++++++++++++++++++++++++++"
    morph :nothing
    TableMonitor.transaction do
      @table_monitor = TableMonitor.find(element.andand.dataset[:id])
      return if @table_monitor.locked_scoreboard

      # noinspection RubyResolve
      if @table_monitor.warmup_modal_should_be_open?
        # noinspection RubyResolve
        warmup_state_change("a") if @table_monitor.warmup? || @table_monitor.warmup_b?
      elsif @table_monitor.shootout_modal_should_be_open?
        @table_monitor.reset_timer!
        @table_monitor.switch_players
      elsif @table_monitor.playing?
        if @table_monitor.data["free_game_form"] == "pool" && @table_monitor.data["playera"].andand["discipline"] != "14.1 endlos"
          @table_monitor.add_n_balls(1, "playera")
        else
          current_role = @table_monitor.data["current_inning"]["active_player"]
          case current_role
          when "playera"
            @table_monitor.reset_timer!
            if @table_monitor.data["current_left_player"] == "playerb"
              @table_monitor.data[current_role]["fouls_1"] = 0
              @table_monitor.terminate_current_inning
            else
              #+++++++
              @table_monitor.add_n_balls((@table_monitor.discipline == "Eurokegel" ? 2 : 1))
            end
            @table_monitor.do_play
            @table_monitor.assign_attributes(panel_state: "pointer_mode", current_element: "pointer_mode")
          when "playerb"
            @table_monitor.reset_timer!
            if @table_monitor.data["current_left_player"] == "playerb"
              #+++++++
              @table_monitor.add_n_balls((@table_monitor.discipline == "Eurokegel" ? 2 : 1))
            else
              @table_monitor.data[current_role]["fouls_1"] = 0
              @table_monitor.terminate_current_inning
            end
            @table_monitor.do_play
            @table_monitor.assign_attributes(panel_state: "pointer_mode", current_element: "pointer_mode")
          else
            # type code here
          end
        end
      elsif (@table_monitor.set_over? && @table_monitor.player_controlled?) || @table_monitor.final_match_score? || @table_monitor.final_set_score?
        @table_monitor.evaluate_result
        # @table_monitor.acknowledge_result!
        # @table_monitor.prepare_final_game_result
      elsif @table_monitor.final_set_score?
        if @table_monitor.tournament_monitor.present?
          @table_monitor.evaluate_result
          # @table_monitor.tournament_monitor.report_result(@table_monitor)
        else
          # noinspection RubyResolve
          # Tournament.logger.info "[table_monitor_reflex#keyb] #{caller[0..4].select{|s| s.include?("/app/").join("\n")}"
          @table_monitor.tournament_monitor.andand.report_result(self)
          @table_monitor.finish_match! if @table_monitor.may_finish_match?
          @table_monitor.reset_table_monitor
        end
      end
      @table_monitor.save
      Rails.logger.info "key_a completed"
    end
  end

  def key_b
    Rails.logger.info "+++++++++++++++++>>> key_b <<<++++++++++++++++++++++++++++++++++++++"
    morph :nothing
    TableMonitor.transaction do
      @table_monitor = TableMonitor.find(element.andand.dataset[:id])
      return if @table_monitor.locked_scoreboard

      # noinspection RubyResolve
      if @table_monitor.warmup_modal_should_be_open?
        # noinspection RubyResolve
        warmup_state_change("b") if @table_monitor.warmup? || @table_monitor.warmup_a?
      elsif @table_monitor.shootout_modal_should_be_open?
        @table_monitor.reset_timer!
        @table_monitor.switch_players
      elsif @table_monitor.playing?
        if @table_monitor.data["free_game_form"] == "pool" && @table_monitor.data["playera"].andand["discipline"] != "14.1 endlos"
          @table_monitor.add_n_balls(1, "playerb")
        else
          current_role = @table_monitor.data["current_inning"]["active_player"]
          case current_role
          when "playerb"
            @table_monitor.reset_timer!
            if @table_monitor.data["current_left_player"] == "playera"
              #+++++++
              @table_monitor.add_n_balls((@table_monitor.discipline == "Eurokegel" ? 2 : 1))
            else
              @table_monitor.data[current_role]["fouls_1"] = 0
              @table_monitor.terminate_current_inning
            end
            @table_monitor.do_play
            @table_monitor.assign_attributes(panel_state: "pointer_mode", current_element: "pointer_mode")
          when "playera"
            @table_monitor.reset_timer!
            if @table_monitor.data["current_left_player"] == "playerb"
              #+++++++
              @table_monitor.add_n_balls((@table_monitor.discipline == "Eurokegel" ? 2 : 1))
            else
              @table_monitor.data[current_role]["fouls_1"] = 0
              @table_monitor.terminate_current_inning
            end
            @table_monitor.do_play
            @table_monitor.assign_attributes(panel_state: "pointer_mode", current_element: "pointer_mode")
          else
            # type code here
          end
        end
      elsif (@table_monitor.set_over? && @table_monitor.player_controlled?) || @table_monitor.final_match_score? || @table_monitor.final_set_score?
        @table_monitor.evaluate_result
        # @table_monitor.acknowledge_result!
        # @table_monitor.prepare_final_game_result
      elsif @table_monitor.final_set_score?
        if @table_monitor.tournament_monitor.present?
          @table_monitor.evaluate_result
          # @table_monitor.tournament_monitor.report_result(@table_monitor)
        else
          # noinspection RubyResolve
          # Tournament.logger.info "[table_monitor_reflex#keyb] #{caller[0..4].select{|s| s.include?("/app/").join("\n")}"
          @table_monitor.tournament_monitor.andand.report_result(self)
          @table_monitor.finish_match! if @table_monitor.may_finish_match?
          @table_monitor.reset_table_monitor
        end
      end
      @table_monitor.save
      Rails.logger.info "key_b completed"
    end
  end

  def key_c
    Rails.logger.info "+++++++++++++++++>>> key_c <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    # noinspection RubyResolve
    if @table_monitor.warmup_modal_should_be_open?
      # noinspection RubyResolve
      if @table_monitor.warmup_a? || @table_monitor.warmup_b?
        # void
      end
    elsif @table_monitor.set_over? || @table_monitor.final_match_score?
      @table_monitor.evaluate_result
      # @table_monitor.acknowledge_result!
      # @table_monitor.prepare_final_game_result
    elsif @table_monitor.final_set_score?
      @table_monitor.evaluate_result
    end
    @table_monitor.save
  end

  def key_d
    Rails.logger.info "+++++++++++++++++>>> key_dc <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    # noinspection RubyResolve
    if @table_monitor.warmup_modal_should_be_open?
      # noinspection RubyResolve
      if @table_monitor.warmup? || @table_monitor.warmup_a? || @table_monitor.warmup_b?
        # start shootout
        @table_monitor.reset_timer!
        @table_monitor.finish_warmup!
      end
    elsif @table_monitor.shootout_modal_should_be_open?
      # start game
      @table_monitor.reset_timer!
      @table_monitor.finish_shootout!
      @table_monitor.evaluate_result
      # @table_monitor.do_play
    elsif @table_monitor.playing?
      @table_monitor.terminate_current_inning if @table_monitor.end_of_set?
    elsif @table_monitor.set_over? || @table_monitor.final_match_score?
      @table_monitor.evaluate_result
      # @table_monitor.acknowledge_result!
      # @table_monitor.prepare_final_game_result
    elsif @table_monitor.final_set_score?
      @table_monitor.evaluate_result
      # @table_monitor.tournament_monitor.report_result(@table_monitor)
    end
    @table_monitor.save
  end

  def undo
    Rails.logger.info "+++++++++++++++++>>> undo <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.panel_state = "inputs"
    @table_monitor.undo
    @table_monitor.save
  end

  def minus_n
    n = element.andand.dataset[:n].to_i
    Rails.logger.info "+++++++++++++++++>>> #{"minus_#{n}"} <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.panel_state = "inputs"
    @table_monitor.current_element = "minus_#{n}"
    @table_monitor.reset_timer!
    @table_monitor.add_n_balls(-n)
    @table_monitor.save
  end

  def switch_players_and_start_game
    Rails.logger.info "+++++++++++++++++>>> switch_players <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    # @table_monitor.panel_state = 'input
    @table_monitor.switch_players
    @table_monitor.reset_timer!
    # noinspection RubyResolve
    @table_monitor.finish_shootout!
    @table_monitor.panel_state = "pointer_mode"
    @table_monitor.do_play
    @table_monitor.save!
    # morph dom_id(@table_monitor), render(@table_monitor)
  end

  def start_game
    Rails.logger.info "+++++++++++++++++>>> start_game <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.reset_timer!
    # noinspection RubyResolve
    @table_monitor.finish_shootout!
    @table_monitor.panel_state = "pointer_mode"
    @table_monitor.do_play
    @table_monitor.save!
    # morph dom_id(@table_monitor), render(@table_monitor)
  end

  def home
    Rails.logger.info "+++++++++++++++++>>> home <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
  end

  def add_n
    Rails.logger.info "+++++++++++++++++>>> #{"add_#{n}"} <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    n = element.andand.dataset[:n].to_i
    @table_monitor.panel_state = "inputs"
    @table_monitor.current_element = "add_#{n}"
    @table_monitor.reset_timer!
    @table_monitor.add_n_balls(n)
    @table_monitor.do_play
    @table_monitor.save
  rescue StandardError => e
    Rails.logger.info("[add_#{n}] ERROR: #{e} #{e.backtrace.to_a.join("\n")}")
  end

  def set_balls
    Rails.logger.info "+++++++++++++++++>>> set_balls <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.panel_state = "inputs"
    @table_monitor.reset_timer!
    @table_monitor.set_n_balls(element.andand.value.to_i)
    @table_monitor.save
  end

  def numbers
    Rails.logger.info "+++++++++++++++++>>> numbers <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.reset_timer!
    @table_monitor.numbers
  end

  def up
    Rails.logger.info "+++++++++++++++++>>> up <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
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
    Rails.logger.info ";;; ERROR: up #{e} #{e.backtrace.to_a.join("\n")}"
  end

  def down
    Rails.logger.info "+++++++++++++++++>>> down <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
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
    Rails.logger.info ";;; down ERROR:  #{e} #{e.backtrace.to_a.join("\n")}"
  end

  def next_step
    Rails.logger.info "+++++++++++++++++>>> next_step <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    Rails.logger.info "next_step from connection #{connection.connection_identifier}"
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.reset_timer!
    @table_monitor.terminate_current_inning
  end

  def admin_ack_result
    Rails.logger.info "+++++++++++++++++>>> admin_ack_result <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    from_admin = element.andand.dataset[:from_admin]
    return if @table_monitor.locked_scoreboard && !from_admin

    @table_monitor.admin_ack_result
  end

  def force_next_state
    Rails.logger.info "+++++++++++++++++>>> force_next_state <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing # true
    from_admin = element.andand.dataset[:from_admin]
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    return if @table_monitor.locked_scoreboard && !from_admin

    @table_monitor.force_next_state
    @table_monitor.save!
  end

  def stop
    Rails.logger.info "+++++++++++++++++>>> stop <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.reset_timer!
    @table_monitor.save
  end

  def warm_up_finished
    Rails.logger.info "+++++++++++++++++>>> warm_up_finished <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.reset_timer!
    # noinspection RubyResolve
    @table_monitor.finish_warmup!
    @table_monitor.save!
  end

  def play_warm_up_a
    Rails.logger.info "+++++++++++++++++>>> play_warm_up_a <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    warmup_state_change("a")
    @table_monitor.save
  end

  def play_warm_up_b
    Rails.logger.info "+++++++++++++++++>>> play_warm_up_b <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    warmup_state_change("b")
    @table_monitor.save
  end

  def balls_left
    Rails.logger.info "+++++++++++++++++>>> balls_left <<<------------------------------------------" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    n_balls_left = element.andand.dataset[:ball_no].to_i
    @table_monitor.balls_left(n_balls_left)
    @table_monitor.do_play
    @table_monitor.assign_attributes(panel_state: "pointer_mode", current_element: "pointer_mode")
    @table_monitor.save
  end

  def foul_two
    Rails.logger.info "+++++++++++++++++>>> foul_two <<<------------------------------------------" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.foul_two
    @table_monitor.do_play
    @table_monitor.assign_attributes(panel_state: "pointer_mode", current_element: "pointer_mode")
    @table_monitor.save!
  end

  def foul_one
    Rails.logger.info "+++++++++++++++++>>> foul_one <<<------------------------------------------" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.foul_one
    @table_monitor.do_play
    @table_monitor.assign_attributes(panel_state: "pointer_mode", current_element: "pointer_mode")
    @table_monitor.save!
  end

  def play
    Rails.logger.info "+++++++++++++++++>>> play <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.panel_state = "timer"
    @table_monitor.current_element = "play"
    @table_monitor.do_play
    @table_monitor.save
  end

  def pause
    Rails.logger.info "+++++++++++++++++>>> pause <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    @table_monitor.assign_attributes(timer_halt_at: Time.now)
    @table_monitor.save
  end

  def timeout
    Rails.logger.info "+++++++++++++++++>>> timeout <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
    morph :nothing
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    # noinspection RubyResolve
    if @table_monitor.playing?
      data = @table_monitor.data
      current_role = data["current_inning"]["active_player"]
      if data["timeout"].to_i.positive? && data[current_role]["tc"].to_i.positive?
        data[current_role]["tc"] = data[current_role]["tc"].to_i - 1
        units = /min$/.match?(@table_monitor.active_timer) ? "minutes" : "seconds"
        delta = if @table_monitor.tournament_monitor.present?
                  @table_monitor.tournament_monitor.tournament.send(@table_monitor.active_timer.to_sym).send(units.to_sym)
                else
                  (data["timeout"].to_i.positive? ? data["timeout"].to_i.seconds : 5.minutes)
                end
        @table_monitor.update(
          timer_halt_at: nil,
          timer_finish_at: @table_monitor.timer_finish_at + delta,
          data: data
        )
      end
    end
  rescue StandardError => e
    Rails.logger.info("[add_one] ERROR: #{e} #{e.backtrace.to_a.join("\n")}")
  end

  private

  def warmup_state_change(player)
    if DEBUG
      Rails.logger.info "+++++++++++++++++>>> #{"warmup_state_change(#{player})"} <<<++++++++++++++++++++++++++++++++++++++"
    end
    # morph :nothing
    other_player = player == "a" ? "b" : "a"
    @table_monitor = TableMonitor.find(element.andand.dataset[:id])
    active_timer = if @table_monitor.send(:"player_#{player}_on_table_before")
                     "time_out_warm_up_follow_up_min"
                   else
                     "time_out_warm_up_first_min"
                   end
    # noinspection RubyResolve
    if @table_monitor.warmup? || @table_monitor.send(:"warmup_#{player}?") || @table_monitor.send(:"warmup_#{other_player}?")
      @table_monitor.send(:"warmup_#{player}!")
      units = "minutes" # active_timer =~ /min$/ ? "minutes" : "seconds"
      start_at = Time.now
      delta = @table_monitor.tournament_monitor.present? ? (@table_monitor.tournament_monitor.tournament.send(active_timer.to_sym) || 5).send(units.to_sym) : 5.minutes
      finish_at = Time.now + delta
      if @table_monitor.timer_halt_at.present?
        extend = Time.now - @table_monitor.timer_halt_at
        start_at += extend
        finish_at += extend
      end
      @table_monitor.update(
        active_timer: active_timer,
        timer_halt_at: nil,
        timer_start_at: start_at,
        timer_finish_at: finish_at
      )
      @table_monitor.update_every_n_seconds(1)
    else
      Time.now
    end
    @table_monitor.save
  rescue StandardError => e
    Rails.logger.info("[add_one] ERROR: #{e} #{e.backtrace.to_a.join("\n")}")
    raise StandardError unless Rails.env == "production"
  end

  def submit
    Rails.logger.info "+++++++++++++++++>>> submit <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
  end

  def discipline
    Rails.logger.info "+++++++++++++++++>>> discipline <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
  end

  def innings
    Rails.logger.info "+++++++++++++++++>>> innings <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
  end

  def balls_goal
    Rails.logger.info "+++++++++++++++++>>> balls_goal <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
  end

  def player_a_name
    Rails.logger.info "+++++++++++++++++>>> player_a_name <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
  end

  def discipline_a
    Rails.logger.info "+++++++++++++++++>>> discipline_a <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
  end

  def balls_goal_a
    Rails.logger.info "+++++++++++++++++>>> balls_goal_a <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
  end

  def player_b_name
    Rails.logger.info "+++++++++++++++++>>> player_b_name <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
  end

  def discipline_b
    Rails.logger.info "+++++++++++++++++>>> discipline_b <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
  end

  def balls_goal_b
    Rails.logger.info "+++++++++++++++++>>> balls_goal_b <<<++++++++++++++++++++++++++++++++++++++" if DEBUG
  end
end
