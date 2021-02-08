class TableMonitorJob < ApplicationJob
  include CableReady::Broadcaster
  queue_as :default

  def perform(*args)
    # periodic update until timer_finish_at is history
    table_monitor, delta, active_player, balls, inning = args
    Rails.logger.info "[TableMonitorJob#perform] delta, active_player, balls, inning: #{[delta, active_player, balls, inning].inspect}"
    if table_monitor.timer_finish_at.present? && (table_monitor.timer_finish_at + 10.seconds) > Time.now
      time_counter, green_bars = table_monitor.get_progress_bar_status(18)

      if table_monitor.timer_halt_at.present? ||
        table_monitor.data["current_inning"]["active_player"] != active_player ||
        table_monitor.data[table_monitor.data["current_inning"]["active_player"]]["innings_redo_list"][-1].to_i != balls ||
        table_monitor.data[table_monitor.data["current_inning"]["active_player"]]["innings"] != inning
        Rails.logger.info "[TableMonitorJob#perform] TERMINATED delta, active_player, balls, inning: #{[delta, active_player, balls, inning].inspect}"
        self
      else
        html = ApplicationController.render(
          partial: "table_monitors/timer",
          locals: { table_monitor: table_monitor, time_counter: time_counter, green_bars: green_bars }
        )
        cable_ready["table-monitor-stream"].inner_html(
          selector: "#timer_table_monitor_#{table_monitor.id}",
          html: html
        )
        cable_ready.broadcast
        enqueue(wait: delta.seconds)
      end
    end
  end
end
