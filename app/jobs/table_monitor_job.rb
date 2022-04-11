class TableMonitorJob < ApplicationJob
  include CableReady::Broadcaster
  queue_as :default

  def perform(*args)
    table_monitor = args[0]

    full_screen_html = ApplicationController.render(
      partial: 'table_monitors/show',
      locals: { table_monitor: table_monitor, full_screen: true }
    )
    cable_ready['table-monitor-stream'].inner_html(
      selector: "#full_screen_table_monitor_#{table_monitor.id}",
      html: full_screen_html
    )
    if table_monitor.tournament_monitor.present?
      html_current_games = ApplicationController.render(
        partial: "tournament_monitors/current_games",
        locals: { tournament_monitor: table_monitor.tournament_monitor }
      )
      cable_ready["table-monitor-stream"].inner_html(
        selector: "#tournament_monitor_current_games_#{table_monitor.tournament_monitor.id}",
        html: html_current_games
      )
      html = ApplicationController.render(
        partial: "table_monitors/show",
        locals: { table_monitor: table_monitor, full_screen: false }
      )
      cable_ready["table-monitor-stream"].inner_html(
        selector: "#table_monitor_#{table_monitor.id}",
        html: html
      )

    end
    cable_ready.broadcast

  end
end
