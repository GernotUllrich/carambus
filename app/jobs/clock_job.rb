class ClockJob < ApplicationJob
  include CableReady::Broadcaster
  queue_as :default

  def perform(*args)
    table_monitor, delta = args
    table_monitor.andand.reload
    if table_monitor.andand.playing_game?
      unless (table_monitor.clock_job_id.present? && table_monitor.clock_job_id != self.job_id)
        clock_html = ApplicationController.render(
          partial: "table_monitors/clock"
        )
        cable_ready["table-monitor-stream"].inner_html(
          selector: "#clock",
          html: clock_html
        )
        cable_ready.broadcast
        table_monitor.update_columns(clock_job_id: self.job_id)
        enqueue(wait: delta.seconds)
        return
      end
    end
    table_monitor.andand.update_columns(clock_job_id: nil)
  end
end
