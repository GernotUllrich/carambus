class TableMonitorLaterJob < ApplicationJob
  include CableReady::Broadcaster
  queue_as :default

  def perform(*args)
    table_monitor = args[0]

    html = ApplicationController.render(
      partial: "table_monitors/show",
      locals: { table_monitor: table_monitor, full_screen: false }
    )

    # html_current_games = ApplicationController.render(
    #   partial: "tournament_monitors/current_games",
    #   locals: { tournament_monitor: table_monitor.tournament_monitor }
    # )
    # cable_ready["table-monitor-stream-later"].inner_html(
    #   selector: "#tournament_monitor_current_games_#{table_monitor.tournament_monitor.andand.id}",
    #   html: html_current_games
    # )
    cable_ready["table-monitor-stream-later"].inner_html(
      selector: "#table_monitor_#{table_monitor.id}",
      html: html
    )
    cable_ready.broadcast

  end
end
