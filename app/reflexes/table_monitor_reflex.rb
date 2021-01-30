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

  def keyup
    begin
      raise Exception
    rescue Exception => e
      e
    end
  end

  def key_a
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    if table_monitor.setup_modal_should_be_open?
      if table_monitor.game_warmup_a_started?
        warmup_state_change ("a")
      end
    elsif table_monitor.shootout_modal_should_be_open?
      table_monitor.switch_players
    elsif table_monitor.playing_game?
      if table_monitor.data["current_inning"]["active_player"] == "playera"
        table_monitor.reset_timer!
        table_monitor.add_n_balls_to_current_players_inning(1)
        table_monitor.do_play
      elsif table_monitor.data["current_inning"]["active_player"] == "playerb"
        table_monitor.reset_timer!
        table_monitor.terminate_current_inning
        table_monitor.do_play
      end
    end
  end

  def key_b
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    if table_monitor.setup_modal_should_be_open?
      if table_monitor.game_warmup_a_started?
        warmup_state_change ("b")
      end
    elsif table_monitor.shootout_modal_should_be_open?
      table_monitor.switch_players
    elsif table_monitor.playing_game?
      if table_monitor.data["current_inning"]["active_player"] == "playerb"
        table_monitor.reset_timer!
        table_monitor.add_n_balls_to_current_players_inning(1)
        table_monitor.do_play
      elsif table_monitor.data["current_inning"]["active_player"] == "playera"
        table_monitor.reset_timer!
        table_monitor.terminate_current_inning
        table_monitor.do_play
      end
    end
  end

  def key_c
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    if table_monitor.setup_modal_should_be_open?
      if table_monitor.game_warmup_a_started? || table_monitor.game_warmup_b_started?
        #void
      end
    elsif table_monitor.shootout_modal_should_be_open?

    end
  end

  def key_d
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    if table_monitor.setup_modal_should_be_open?
      if table_monitor.game_warmup_a_started? || table_monitor.game_warmup_b_started?
        #start shoot-out
        table_monitor.reset_timer!
        table_monitor.event_warmup_finished!
      end
    elsif table_monitor.shootout_modal_should_be_open?
      #start game
      table_monitor.reset_timer!
      table_monitor.event_shootout_finished!
      table_monitor.do_play
    elsif table_monitor.playing_game?
      if table_monitor.end_result?
        table_monitor.terminate_current_inning
      end
    end
  end

  def undo
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    table_monitor.undo
  end

  def minus_one
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    table_monitor.reset_timer!
    table_monitor.add_n_balls_to_current_players_inning(-1)
  end

  def switch_players
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    table_monitor.switch_players
  end

  def start_game
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    table_monitor.reset_timer!
    table_monitor.event_shootout_finished!
  end

  def add_one
    begin
      morph :nothing
      table_monitor = TableMonitor.find(element.dataset[:id])
      table_monitor.reset_timer!
      table_monitor.add_n_balls_to_current_players_inning(1)
      Rails.logger.info("[add_one] ++++1++++")
    rescue Exception => e
      Rails.logger.info("[add_one] #{e} #{e.backtrace.join("\n")}")
    end
  end

  def set_balls
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    table_monitor.reset_timer!
    table_monitor.set_n_balls_to_current_players_inning(element.value.to_i)
  end

  def add_ten
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    table_monitor.reset_timer!
    table_monitor.add_n_balls_to_current_players_inning(10)
  end

  def numbers
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    if TableMonitor::NNN == "db"
      table_monitor.update_attributes(nnn: nil)
    else
      session[:"nnn_#{element.dataset[:id]}"] = nil
    end
    table_monitor.numbers
  end

  def up
    begin
      morph :nothing
      table_monitor = TableMonitor.find(element.dataset[:id])
      t_no = table_monitor.name.match(/table(\d+)/).andand[1].to_i
      switch_to = table_monitor.tournament_monitor.table_monitors.map { |tm| tm.name.match(/table(\d+)/).andand[1].to_i }.sort
      ix = switch_to.index(t_no)
      ix2 = ix + switch_to.length
      switch_to = switch_to + switch_to
      new_t_no = switch_to[ix2 - 1]
      tm1 = table_monitor
      tm2 = table_monitor.tournament_monitor.table_monitors.where(name: "table#{new_t_no}").first
      game1 = tm1.game
      Rails.logger.info ";;; game1.id=#{game1.andand.id}, tm1: #{JSON.pretty_generate(tm1.attributes)}"
      game2 = tm2.game
      Rails.logger.info ";;; game2.id=#{game2.andand.id}, tm2: #{JSON.pretty_generate(tm2.attributes)}"
      tm1_data = tm1.data.dup
      tm2_data = tm2.data.dup
      tm1.update_attributes(game_id: game2.id, data: tm2_data)
      tm2.update_attributes(game_id: game1.id, data: tm1_data)
    rescue Exception => e
      Rails.logger.info ";;; up #{e} #{e.backtrace.join("\n")}"
    end
  end

  def down
    begin
      morph :nothing
      table_monitor = TableMonitor.find(element.dataset[:id])
      t_no = table_monitor.name.match(/table(\d+)/).andand[1].to_i
      switch_to = table_monitor.tournament_monitor.table_monitors.map { |tm| tm.name.match(/table(\d+)/).andand[1].to_i }.sort
      ix = switch_to.index(t_no)
      switch_to = switch_to + switch_to
      new_t_no = switch_to[ix + 1]
      tm1 = table_monitor
      tm2 = table_monitor.tournament_monitor.table_monitors.where(name: "table#{new_t_no}").first
      game1 = tm1.game
      Rails.logger.info ";;; game1.id=#{game1.andand.id}, tm1: #{JSON.pretty_generate(tm1.attributes)}"
      game2 = tm2.game
      Rails.logger.info ";;; game2.id=#{game2.andand.id}, tm2: #{JSON.pretty_generate(tm2.attributes)}"
      tm1_data = tm1.data.dup
      tm2_data = tm2.data.dup
      tm1.update_attributes(game_id: game2.id, data: tm2_data)
      tm2.update_attributes(game_id: game1.id, data: tm1_data)
    rescue Exception => e
      Rails.logger.info ";;; down #{e} #{e.backtrace.join("\n")}"
    end
  end

  def next_step
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    table_monitor.reset_timer!
    table_monitor.terminate_current_inning
  end

  def force_next_state
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    if [:game_setup_started, :game_warmup_a_started, :game_warmup_b_started].include?(table_monitor.state.to_sym)
      table_monitor.reset_timer!
      table_monitor.event_warmup_finished!
    elsif [:game_shootout_started].include?(table_monitor.state.to_sym)
      table_monitor.reset_timer!
      table_monitor.event_shootout_finished!
    end
  end

  def stop
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    table_monitor.reset_timer!
  end

  def warm_up_finished
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    table_monitor.reset_timer!
    table_monitor.event_warmup_finished!
  end

  def play_warm_up_a
    warmup_state_change ("a")
  end

  def play_warm_up_b
    warmup_state_change ("b")
  end

  def play
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    table_monitor.do_play
  end

  def pause
    morph :nothing
    table_monitor = TableMonitor.find(element.dataset[:id])
    table_monitor.update_attributes(timer_halt_at: Time.now)
  end

  private

  def warmup_state_change (player)
    morph :nothing
    other_player = player == 'a' ? 'b' : 'a'
    table_monitor = TableMonitor.find(element.dataset[:id])
    active_timer = table_monitor.send(:"player_#{player}_has_played_on_table_before") ?
                     "time_out_warm_up_follow_up_min" :
                     "time_out_warm_up_first_min"
    if (table_monitor.game_setup_started? || table_monitor.send(:"game_warmup_#{player}_started?") || table_monitor.send(:"game_warmup_#{other_player}_started?"))
      table_monitor.send(:"event_play_warm_up_#{player}!")
      units = active_timer =~ /min$/ ? "minutes" : "seconds"
      start_at = Time.now
      finish_at = Time.now + table_monitor.tournament_monitor.tournament.send(active_timer.to_sym).send(units.to_sym)
      if table_monitor.timer_halt_at.present?
        extend = Time.now - table_monitor.timer_halt_at
        start_at = start_at + extend
        finish_at = finish_at + extend
      end
      table_monitor.update_attributes(
        active_timer: active_timer,
        timer_halt_at: nil,
        timer_start_at: start_at,
        timer_finish_at: finish_at)
      table_monitor.update_every_n_seconds(10);
    end
  end
end
