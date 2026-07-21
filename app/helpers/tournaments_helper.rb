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

  # Plan 26-01: Vereinsauswahl für die Meldeliste eines Region-Turniers.
  #
  # Liefert [[label, id], ...] für ein select — Vereine der ausrichtenden Region, "die wichtigsten
  # zuerst", ohne neue Datenhaltung und ohne Konfiguration:
  #   1. Vereine, aus denen bereits Teilnehmer DIESES Turniers gemeldet sind (wächst mit der Meldung)
  #   2. Verein(e) des Austragungsorts
  #   3. alle übrigen alphabetisch
  # Ist keine Region bestimmbar, bleibt die Liste leer — der Helfer errät nichts.
  def entry_list_clubs_for(tournament)
    region = tournament.region || (tournament.organizer if tournament.organizer.is_a?(Region))
    return [] if region.blank?

    clubs = Club.where(region_id: region.id).order(:name).to_a
    return [] if clubs.empty?

    # Vereinszugehörigkeit über SeasonParticipation der TURNIERSAISON — dieselbe Quelle wie
    # TournamentsController#players_by_club. (Player hat zwar eine club_id-Spalte, aber kein
    # belongs_to :club; maßgeblich ist season_participations.club_id.)
    seeded_player_ids = tournament.seedings.pluck(:player_id).compact
    seeded_club_ids = if seeded_player_ids.any?
      SeasonParticipation
        .where(player_id: seeded_player_ids, season_id: tournament.season_id)
        .pluck(:club_id).compact.to_set
    else
      Set.new
    end
    # Location hat KEIN belongs_to :club (club_id ist ignored_column) — der Bezug läuft über
    # club_locations, es können mehrere Vereine an einem Spielort sein.
    location_club_ids = Array(tournament.location&.clubs&.map(&:id)).to_set

    ranked, rest = clubs.partition { |c| seeded_club_ids.include?(c.id) || location_club_ids.include?(c.id) }
    # Innerhalb der Vorauswahl: Vereine mit Meldungen vor reinen Austragungsort-Vereinen.
    ranked.sort_by! { |c| [seeded_club_ids.include?(c.id) ? 0 : 1, c.name.to_s] }

    ranked.map { |c| [c.name, c.id] } + rest.map { |c| [c.name, c.id] }
  end
end
