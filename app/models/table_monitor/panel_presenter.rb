# frozen_string_literal: true

# TableMonitor::PanelPresenter
#
# Read-only presentation/view-data collaborator for TableMonitor. Receives a
# TableMonitor instance and carries the modal-visibility predicates, the innings
# render helpers, the AASM-state display string and the progress-bar computation
# that used to live in TableMonitor.
#
# All methods are read-only (no save!/data_will_change!/AASM mutation). Rendering
# internals stay in TableMonitor::ScoreEngine (render_* delegate there). Behaviour
# is preserved verbatim (rescue contracts: re-raise vs. false; I18n key selection),
# pinned by test/models/table_monitor/panel_presentation_characterization_test.rb.
class TableMonitor::PanelPresenter
  def initialize(table_monitor)
    @table_monitor = table_monitor
  end

  def state_display(locale)
    @locale = locale || I18n.default_locale
    @game_or_set = if @table_monitor.data["sets_to_play"].to_i > 1
      I18n.t("table_monitor.set_finished")
    else
      I18n.t("table_monitor.final_set_score")
    end
    if @table_monitor.state == "set_over"
      I18n.t("table_monitor.status.set_over",
        game_or_set_finished: @game_or_set,
        wait_check: @table_monitor.player_controlled? ? I18n.t("table_monitor.status.wait_check") : "")
    else
      I18n.t("table_monitor.status.#{@table_monitor.state}")
    end
  rescue => e
    Rails.logger.error "ERROR: m6[#{@table_monitor.id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def render_innings_list(role)
    @table_monitor.score_engine.render_innings_list(role)
  rescue => e
    Rails.logger.error "ERROR:m6[#{@table_monitor.id}] #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end

  def render_last_innings(last_n, role)
    @table_monitor.score_engine.render_last_innings(last_n, role)
  rescue => e
    Rails.logger.error "ERROR in render_last_innings: #{e.class}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace&.first(10)&.join("\n")}"
    Rails.logger.error "Data: role=#{role}, innings_list=#{@table_monitor.data[role].andand["innings_list"].inspect}, innings_redo_list=#{@table_monitor.data[role].andand["innings_redo_list"].inspect}"
    raise StandardError, "render_last_innings failed: #{e.message}" unless Rails.env == "production"
  end

  def warmup_modal_should_be_open?
    @table_monitor.warmup? || @table_monitor.warmup_a? || @table_monitor.warmup_b?
  rescue => e
    Rails.logger.error "ERROR: m6[#{@table_monitor.id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def shootout_modal_should_be_open?
    @table_monitor.match_shootout?
  rescue => e
    Rails.logger.error "ERROR: m6[#{@table_monitor.id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def numbers_modal_should_be_open?
    @table_monitor.nnn.present? || @table_monitor.panel_state == "numbers"
  rescue => e
    Rails.logger.error "ERROR: m6[#{@table_monitor.id}]#{e}, #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def protocol_modal_should_be_open?
    %w[protocol protocol_edit protocol_final].include?(@table_monitor.panel_state)
  rescue => e
    Rails.logger.error "ERROR: m6[#{@table_monitor.id}]#{e}, #{e.backtrace&.join("\n")}"
    false
  end

  def foul_modal_should_be_open?
    @table_monitor.panel_state == "foul"
  rescue => e
    Rails.logger.error "ERROR: foul_modal_should_be_open?[#{@table_monitor.id}]#{e}, #{e.backtrace&.join("\n")}"
    false
  end

  def snooker_inning_edit_modal_should_be_open?
    @table_monitor.panel_state == "snooker_inning_edit"
  rescue => e
    Rails.logger.error "ERROR: snooker_inning_edit_modal_should_be_open?[#{@table_monitor.id}]#{e}, #{e.backtrace&.join("\n")}"
    false
  end

  def final_protocol_modal_should_be_open?
    @table_monitor.panel_state == "protocol_final"
  rescue => e
    Rails.logger.error "ERROR: m6[#{@table_monitor.id}]#{e}, #{e.backtrace&.join("\n")}"
    false
  end

  def get_progress_bar_status(n_bars)
    Rails.logger.debug do
      "------------m6[#{@table_monitor.id}]--------->>> get_progress_bar_status(#{n_bars}) <<<------------------------------------------"
    end
    time_counter = green_bars = do_green_bars = do_yellow_bars = do_orange_bars = do_lightred_bars = do_red_bars = 0
    finish = @table_monitor.timer_finish_at
    start = @table_monitor.timer_start_at
    Rails.logger.debug { "[table_monitor#get_progress_bar_status] finish, start: #{[finish, start].inspect}" }
    if finish.present? && @table_monitor.timer_halt_at.present?
      Rails.logger.debug { "[table_monitor#get_progress_bar_status] finish.present && timer_halt_at.present ..." }
      halted = Time.now.to_i - @table_monitor.timer_halt_at.to_i
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
      units = /min$/.match?(@table_monitor.active_timer) ? "minutes" : "seconds"
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
      do_green_bars = (do_bars - 40).clamp(0, 10)
      do_yellow_bars = (do_bars - 30).clamp(0, 10)
      do_orange_bars = (do_bars - 20).clamp(0, 10)
      do_lightred_bars = (do_bars - 10).clamp(0, 10)
      do_red_bars = do_bars.clamp(0, 10)
      Rails.logger.debug do
        "[table_monitor#get_progress_bar_status] m6[#{@table_monitor.id}]time_counter, green_bars: #{[time_counter, green_bars].inspect}"
      end
    end
    Rails.logger.debug do
      "[table_monitor#get_progress_bar_status] m6[#{@table_monitor.id}]return [time_counter, green_bars]: #{[time_counter, green_bars].inspect}"
    end
    [time_counter, green_bars, do_green_bars, do_yellow_bars, do_orange_bars, do_lightred_bars, do_red_bars]
  rescue => e
    Rails.logger.error "ERROR: #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError unless Rails.env == "production"
  end
end
