class TournamentStatusUpdateJob < ApplicationJob
  include CableReady::Broadcaster
  queue_as :default
  
  # Verhindere Duplikate: Wenn ein Job für dasselbe Tournament bereits geplant ist,
  # überspringe den neuen Job (wird durch Throttle-Mechanismus im TableMonitor gehandhabt)
  # Zusätzlich: Discard wenn das Tournament nicht mehr existiert
  discard_on ActiveRecord::RecordNotFound
  
  def perform(tournament)
    return unless tournament.present?
    
    tournament_id = tournament.id
    tournament_monitor = tournament.tournament_monitor
    
    Rails.logger.info "TournamentStatusUpdateJob: Processing tournament #{tournament_id}"
    
    # Nur broadcasten wenn Tournament Monitor vorhanden und Turnier läuft/abgeschlossen
    unless tournament_monitor.present?
      Rails.logger.info "TournamentStatusUpdateJob: No tournament_monitor for tournament #{tournament_id}"
      return
    end
    
    unless tournament.tournament_started || 
           %w[playing_groups playing_finals finals_finished results_published].include?(tournament.state)
      Rails.logger.info "TournamentStatusUpdateJob: Tournament #{tournament_id} not started yet (state: #{tournament.state})"
      return
    end
    
    # Rendere das Status-Partial mit ApplicationController.renderer
    # Erstelle einen Renderer mit Mock-Warden um Warden-Probleme zu vermeiden
    html_status = begin
      renderer = ApplicationController.renderer.new(
        http_host: 'localhost',
        https: false,
        method: 'GET',
        script_name: ''
      )
      renderer.render(
        partial: "tournaments/tournament_status",
        locals: { tournament: tournament }
      )
    rescue => e
      Rails.logger.error "TournamentStatusUpdateJob: Render failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Fallback: Wenn Render fehlschlägt, versuche mit Fallback-Methode
      render_with_fallback(tournament: tournament)
    end
    
    Rails.logger.info "TournamentStatusUpdateJob: Broadcasting to tournament-stream-#{tournament_id}"
    
    # Broadcast Status-Update
    cable_ready["tournament-stream-#{tournament_id}"].inner_html(
      selector: "#tournament-status-container-#{tournament_id}",
      html: html_status
    )
    
    cable_ready.broadcast
    
    Rails.logger.info "TournamentStatusUpdateJob: Broadcast completed for tournament #{tournament_id}"
  rescue StandardError => e
    Rails.logger.error "TournamentStatusUpdateJob error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  # Fallback: Rendert mit einem Controller der Callbacks überspringt
  def render_with_fallback(tournament:)
    # Erstelle einen Controller ohne Callbacks
    controller_class = Class.new(ApplicationController) do
      # Überspringe alle before_action Callbacks
      skip_before_action :check_mini_profiler, raise: false
      skip_before_action :set_paper_trail_whodunnit, raise: false
      skip_before_action :set_model_class, raise: false
      skip_before_action :set_user_preferences, raise: false
      skip_before_action :set_locale, raise: false
      skip_before_action :set_cache_headers, raise: false
      skip_before_action :handle_menu_state, raise: false
      skip_around_action :set_current_user, raise: false
      
      # Überschreibe current_user um nil zurückzugeben
      def current_user
        nil
      end
      
      # Überschreibe warden um nil zurückzugeben
      def warden
        nil
      end
    end
    
    # Rendere mit diesem Controller
    controller_class.render(
      partial: "tournaments/tournament_status",
      locals: { tournament: tournament }
    )
  end
end

