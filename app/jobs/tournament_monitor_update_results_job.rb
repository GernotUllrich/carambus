class TournamentMonitorUpdateResultsJob < ApplicationJob
  include CableReady::Broadcaster
  queue_as :default

  def perform(*args)
    tournament_monitor = args[0]
    html_game_results = ApplicationController.render(
      partial: "tournament_monitors/game_results",
      locals: { tournament_monitor: tournament_monitor }
    )
    html_rankings = ApplicationController.render(
      partial: "tournament_monitors/rankings",
      locals: { tournament_monitor: tournament_monitor, totals: true }
    )
    cable_ready["tournament-monitor-stream"].inner_html(
      selector: "#tournament_monitor_game_results_#{tournament_monitor.id}",
      html: html_game_results
    )
    cable_ready["tournament-monitor-stream"].inner_html(
      selector: "#tournament_monitor_rankings_#{tournament_monitor.id}",
      html: html_rankings
    )
    cable_ready.broadcast
  end
end
