class TournamentStatusUpdateJob < ApplicationJob
  include CableReady::Broadcaster
  queue_as :default

  def perform(tournament)
    return unless tournament.present?
    
    tournament_id = tournament.id
    tournament_monitor = tournament.tournament_monitor
    
    # Nur broadcasten wenn Tournament Monitor vorhanden und Turnier läuft/abgeschlossen
    return unless tournament_monitor.present?
    return unless tournament.tournament_started || 
                  %w[playing_groups playing_finals finals_finished results_published].include?(tournament.state)
    
    # Rendere das Status-Partial
    html_status = ApplicationController.render(
      partial: "tournaments/tournament_status",
      locals: { tournament: tournament }
    )
    
    # Broadcast Status-Update
    cable_ready["tournament-stream-#{tournament_id}"].inner_html(
      selector: "#tournament-status-container-#{tournament_id}",
      html: html_status
    )
    
    cable_ready.broadcast
  rescue StandardError => e
    Rails.logger.error "TournamentStatusUpdateJob error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end

