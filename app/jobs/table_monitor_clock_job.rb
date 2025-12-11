class TableMonitorClockJob < ApplicationJob
  include CableReady::Broadcaster
  queue_as :default
  # around_perform :avoid_multiple_invocation
  def perform(*args)
    # Skip execution on API Server (no scoreboards running)
    # Local servers are identified by having a carambus_api_url configured
    unless ApplicationRecord.local_server?
      Rails.logger.info "📡 TableMonitorClockJob skipped (API Server - no scoreboards)"
      return
    end

    Rails.logger.silence do
      # periodic update until timer_finish_at is history
      table_monitor, delta, active_player, balls, inning = args
      table_monitor.reload
      Rails.logger.info "[TableMonitorClockJob#perform] monit: #{table_monitor.timer_job_id} self: #{job_id}"
      Rails.logger.info "[TableMonitorClockJob#perform] delta, active_player, balls, inning: #{[delta, active_player,
                                                                                                balls, inning].inspect}"
      if table_monitor.timer_finish_at.present? && (table_monitor.timer_finish_at + 10.seconds) > Time.now
        Rails.logger.info "[TableMonitorClockJob#perform] #{table_monitor.timer_finish_at}, #{Time.now.utc}, delta, active_player, balls, inning: #{[
          delta, active_player, balls, inning
        ].inspect}"
        time_counter, green_bars, do_green_bars, do_yellow_bars, do_orange_bars, do_lightred_bars, do_red_bars = table_monitor.get_progress_bar_status(18)

        if table_monitor.timer_halt_at.present? || (table_monitor.timer_job_id.present? && table_monitor.timer_job_id != job_id)
          Rails.logger.info "[TableMonitorClockJob#perform] TERMINATED delta, active_player, balls, inning: #{[delta,
                                                                                                               active_player, balls, inning].inspect}"
          self
        else
          html = ApplicationController.render(
            partial: "table_monitors/timer",
            locals: { table_monitor: table_monitor, time_counter: time_counter, green_bars: green_bars }
          )
          html_new = ApplicationController.render(
            partial: "table_monitors/timer_new",
            locals: { table_monitor: table_monitor, time_counter: time_counter, do_green_bars: do_green_bars,
                      do_yellow_bars: do_yellow_bars, do_orange_bars: do_orange_bars, do_lightred_bars: do_lightred_bars, do_red_bars: do_red_bars }
          )
          cable_ready["table-monitor-stream"].inner_html(
            selector: "#timer_table_monitor_#{table_monitor.id}",
            html: html
          )
          cable_ready["table-monitor-stream"].inner_html(
            selector: "#timer_new_table_monitor_#{table_monitor.id}",
            html: html_new
          )
          cable_ready.broadcast
          table_monitor.update_columns(timer_job_id: job_id)
          enqueue(wait: delta.seconds)
          return
        end
      else
        # Rails.logger.info "[TableMonitorClockJob#perform] OOPS"
      end
      table_monitor.update_columns(timer_job_id: nil)
      # else
      # end
    end
  rescue Exception => e
    Rails.logger.info "[TableMonitorClockJob#perform] #{e}"
  end

  private

  def avoid_multiple_invocation
    true
  end
end
