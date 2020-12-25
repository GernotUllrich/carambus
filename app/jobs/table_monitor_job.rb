class TableMonitorJob < ApplicationJob
  include CableReady::Broadcaster
  queue_as :default

  def perform(*args)
    # periodic update until timer_finish_at is history
    table_monitor, delta = args
    if table_monitor.timer_finish_at.present? && (table_monitor.timer_finish_at + 10.seconds) > Time.now
      table_monitor.touch
      enqueue(wait: delta.seconds) unless table_monitor.timer_halt_at.present?
    end
  end
end
