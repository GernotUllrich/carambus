module TournamentsHelper
end

module TournamentsHelper
  def hash_diff(first, second)
    first
      .dup
      .delete_if { |k, v| second[k] == v }
      .merge!(second.dup.delete_if { |k, _v| first.has_key?(k) })
  end

  # Prüft ob Turnier läuft oder abgeschlossen ist
  def tournament_active_or_finished?(tournament)
    tournament.tournament_started || 
    %w[playing_groups playing_finals finals_finished results_published].include?(tournament.state)
  end

  # Gibt Tournament Monitor zurück falls vorhanden
  def tournament_monitor_for_status(tournament)
    tournament.tournament_monitor
  end

  # Berechnet Gruppen für Status-Anzeige
  def tournament_groups_for_status(tournament)
    return nil unless tournament.tournament_plan.present?
    
    tournament_monitor = tournament.tournament_monitor
    return nil unless tournament_monitor.present?
    
    # Versuche Gruppen aus Tournament Monitor zu holen
    if tournament_monitor.data['groups'].present?
      tournament_monitor.data['groups']
    else
      # Berechne Gruppen neu
      has_local_seedings = tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").any?
      seeding_scope = has_local_seedings ? 
                      "seedings.id >= #{Seeding::MIN_ID}" : 
                      "seedings.id < #{Seeding::MIN_ID}"
      
      TournamentMonitor.distribute_to_group(
        tournament.seedings.where.not(state: "no_show").where(seeding_scope).order(:position).map(&:player), 
        tournament.tournament_plan.ngroups,
        tournament.tournament_plan.group_sizes
      )
    end
  end

  # Gibt aktuelle Runde zurück
  def tournament_current_round(tournament)
    tournament.tournament_monitor&.current_round
  end

  # Gibt Anzahl gespielter vs. gesamt Spiele zurück
  def tournament_games_progress(tournament)
    game_scope = tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").count > 0 ? 
                 "games.id >= #{Game::MIN_ID}" : 
                 "games.id < #{Game::MIN_ID}"
    
    total_games = tournament.games.where(game_scope).count
    finished_games = tournament.games.where(game_scope).where.not(ended_at: nil).count
    
    { finished: finished_games, total: total_games }
  end

  # Prüft ob User Spielleiter ist (club_admin)
  def tournament_director?(user)
    user&.club_admin? || user&.system_admin?
  end
end
