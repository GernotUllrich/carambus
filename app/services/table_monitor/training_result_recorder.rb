# frozen_string_literal: true

# Schreibt das Endergebnis eines freien TRAININGSSPIELS in die GameParticipations
# (Milestone v0.3, Plan 01-01).
#
# Warum es diesen Service gibt:
# Im Turnier- und Ligabetrieb verbuchen TournamentMonitor::ResultProcessor bzw.
# PartyMonitor::ResultProcessor die Statistikfelder. Im Training gibt es keinen
# tournament_monitor — TableMonitor::ResultRecorder#perform_evaluate_result ruft
# `@tm.tournament_monitor&.report_result(@tm)` (result_recorder.rb:510-531), was per
# Safe-Navigation zum No-op wird. Das Spiel landet korrekt in :final_match_score und
# bekommt via set_end_time sein ended_at, aber points/result/innings/gd/hs/sets blieben
# bisher NULL. Genau diese Luecke schliesst dieser Service.
#
# Aufruf: als after-Callback des bestehenden finish_match-Events
# (TableMonitor#record_training_result). Der Service ist fuer alle Nicht-Trainingsfaelle
# ein No-op, damit Turnier- und Ligapfad unveraendert bleiben.
#
# Verwendung:
#   TableMonitor::TrainingResultRecorder.call(table_monitor: tm)
class TableMonitor::TrainingResultRecorder < ApplicationService
  # SeasonParticipation-Status, dessen Spiele NICHT in die Statistik eingehen.
  # Deckt beide Faelle ab (Gernot-Regel 2026-08-28):
  #   - die festen Platzhalter "Gast A"/"Gast B" am Scoreboard (Player.default_guest)
  #   - temporaer angelegte Gaeste aus anderen Clubs (werden per Cron in
  #     Player.remove_inactive_guests wieder abgeraeumt)
  # Passive Vereinsmitglieder sind NICHT "guest" und zaehlen deshalb mit.
  GUEST_STATUS = "guest"

  def initialize(kwargs = {})
    @tm = kwargs[:table_monitor]
  end

  def call
    return false unless applicable?

    write_participations
    true
  rescue => e
    # Eine fehlgeschlagene Ergebnisverbuchung darf die Finalisierung nie verhindern —
    # gleiche Haltung wie set_end_time (table_monitor.rb:856-858).
    Rails.logger.error "ERROR: TrainingResultRecorder[#{@tm&.id}]#{e}, #{e.backtrace&.join("\n")}"
    false
  end

  private

  def game
    @game ||= @tm&.game
  end

  # Nur freie Trainingsspiele zweier wertbarer Spieler.
  def applicable?
    return false if @tm.blank?
    # Turnier/Liga verbuchen selbst — hier nicht eingreifen.
    return false if @tm.tournament_monitor.present?
    return false if game.blank?
    return false unless Game.training.exists?(game.id)
    return false if participations.size != 2
    return false if participations.any? { |gp| excluded_player_ids.include?(gp.player_id) }

    true
  end

  def participations
    @participations ||= %w[playera playerb].filter_map { |role| game.game_participations.find_by(role: role) }
  end

  # Rein lesende Ermittlung der nicht wertbaren Spieler.
  #
  # ⚠️ Bewusst NICHT Player.default_guest verwenden: die Methode LEGT fehlende
  # Gast-Datensaetze an (player.rb:159-164) — eine Guard-Pruefung darf nichts erzeugen.
  # ⚠️ Bewusst NICHT ueber den Namen matchen: es gibt reale Spieler mit Nachnamen
  # "Gast"/"Gastinger", die ein LIKE 'Gast%' faelschlich ausschliessen wuerde.
  # ⚠️ Bewusst NICHT `status = "active"` verlangen (Pruefung aus
  # ExternalTournament::ClubRosterQuery): das ist Turnier-Spielberechtigung und wuerde
  # passive Vereinsmitglieder ausschliessen, die laut Regel mitzaehlen sollen.
  def excluded_player_ids
    @excluded_player_ids ||= begin
      season = Season.current_season
      if season.blank?
        []
      else
        scope = SeasonParticipation.where(season_id: season.id, status: GUEST_STATUS)
        # Club-Scope wenn ermittelbar; sonst saisonweit pruefen (strenger, nie laxer).
        club = @tm.table&.location&.club
        scope = scope.where(club_id: club.id) if club.present?
        scope.pluck(:player_id)
      end
    end
  end

  # Spielkontext, der die Finalisierung ueberleben muss (Plan 02-01).
  #
  # Warum ueberhaupt kopiert wird: Disziplin und Distanz stehen ausschliesslich in
  # table_monitors.data und werden vom naechsten Spiel am selben Tisch ueberschrieben.
  # Ohne diese Kopie traegt ein abgeschlossenes Trainingsspiel keinerlei Angabe darueber,
  # WAS gespielt wurde — weder das Ranking "schon mit diesen Parametern gespielt"
  # (Plan 02-02) noch die Auswertung "GD/HS pro Disziplin" (Phase 3) waeren moeglich.
  #
  # Die Aufteilung folgt der Struktur von @tm.data: balls_goal und discipline stehen
  # dort PRO ROLLE (bei Handicap unterscheiden sie sich zwischen den Spielern),
  # innings_goal und sets_to_play gemeinsam auf oberster Ebene.
  PARTICIPATION_CONTEXT_KEYS = %w[discipline balls_goal].freeze
  GAME_CONTEXT_KEYS = %w[innings_goal sets_to_play].freeze

  # Wertberechnung wie im Turnierpfad fuer sets_to_play <= 1
  # (tournament_monitor/result_processor.rb:524-541). Trainingsspiele sind Einzelsaetze.
  def write_participations
    values = participations.index_by(&:role).transform_values { |gp| computed_values(gp.role) }
    points = points_for(values)

    participations.each do |gp|
      v = values[gp.role]
      gp.update(
        points: points[gp.role],
        result: v[:result],
        innings: v[:innings],
        gd: v[:gd],
        hs: v[:hs],
        sets: 1,
        data: (gp.data || {}).merge(participation_context(gp.role))
      )
    end

    game.update(data: (game.data || {}).merge(game_context))
  end

  # ⚠️ Bewusst nur die benannten Schluessel kopieren, nie @tm.data als Ganzes:
  # der Monitor-Hash enthaelt u.a. innings_list/balls_counter_stack (Laufzeitzustand)
  # und waechst mit jedem Stoss. Fehlende Schluessel werden weggelassen (compact),
  # nicht als nil eingetragen.
  def participation_context(role)
    (@tm.data[role] || {}).slice(*PARTICIPATION_CONTEXT_KEYS).compact
  end

  # ⚠️ Hier darf niemals ein Schluessel "external_id" entstehen — Game.training
  # filtert per LIKE auf genau diese Zeichenkette in games.data (game.rb:62); das
  # Spiel wuerde sich sonst selbst aus dem Trainings-Scope werfen. Die Whitelist
  # oben stellt das sicher.
  def game_context
    (@tm.data || {}).slice(*GAME_CONTEXT_KEYS).compact
  end

  def computed_values(role)
    source = @tm.data[role] || {}
    result = source["result"].to_i
    innings = source["innings"].to_i
    {
      result: result,
      innings: innings,
      hs: source["hs"].to_i,
      # innings kann 0 sein (abgebrochenes Spiel) — der Turnierpfad faengt das nicht ab,
      # hier darf keine Division durch Null nach gd durchschlagen.
      gd: innings.positive? ? format("%.2f", result.to_f / innings).to_f : 0.0
    }
  end

  # Siegpunkte wie im Turnierbetrieb: 2 fuer den Sieger, 0 fuer den Verlierer,
  # je 1 bei Gleichstand.
  def points_for(values)
    a = values["playera"][:result]
    b = values["playerb"][:result]
    if a == b
      {"playera" => 1, "playerb" => 1}
    elsif a > b
      {"playera" => 2, "playerb" => 0}
    else
      {"playera" => 0, "playerb" => 2}
    end
  end
end
