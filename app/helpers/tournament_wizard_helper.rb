# frozen_string_literal: true

module TournamentWizardHelper
  # Bestimmt den aktuellen Wizard-Schritt basierend auf Tournament State
  def wizard_current_step(tournament)
    case tournament.state
    when "new_tournament"
      1 # Setzliste aktualisieren
    when "accreditation_finished"
      3 # Rangliste abschließen (Sortierung bereits erfolgt)
    when "tournament_seeding_finished"
      5 # Turniermodus wählen
    when "tournament_mode_defined"
      6 # Turnier starten
    when "tournament_started", "playing_groups", "playing_finals"
      7 # Läuft
    when "finals_finished", "results_published"
      8 # Abgeschlossen
    else
      1
    end
  end

  # Gibt den Status eines spezifischen Schritts zurück
  def wizard_step_status(tournament, step_number)
    current = wizard_current_step(tournament)

    if step_number < current
      :completed
    elsif step_number == current
      :active
    else
      :pending
    end
  end

  # Fortschritt in Prozent
  def wizard_progress_percent(tournament)
    current = wizard_current_step(tournament)
    [(current - 1) * 100.0 / 6.0, 100].min.round
  end

  # Status-Text
  def wizard_status_text(tournament)
    case wizard_current_step(tournament)
    when 1..2 then "Vorbereitung"
    when 3..4 then "Setzliste konfigurieren"
    when 5 then "Modus-Auswahl"
    when 6 then "Bereit zum Start"
    when 7 then "Turnier läuft"
    when 8 then "Abgeschlossen"
    else "Vorbereitung"
    end
  end

  # Icon für Schritt-Status
  def step_icon(status)
    case status
    when :completed then "✅"
    when :active then "▶️"
    when :pending then "⏸️"
    end
  end

  # CSS-Klasse für Schritt
  def step_class(status)
    case status
    when :completed then "wizard-step-completed"
    when :active then "wizard-step-active"
    when :pending then "wizard-step-pending"
    end
  end

  # Sync Info Text
  def sync_info_text(tournament)
    if tournament.sync_date
      "Zuletzt: #{time_ago_in_words(tournament.sync_date)} her"
    else
      "Noch nicht synchronisiert"
    end
  end

  # Spieleranzahl-Info
  def seedings_info_text(tournament)
    active_count = tournament.seedings.where.not(state: "no_show").count
    "#{active_count} Spieler"
  end

  # Turniermodus-Info
  def mode_info_text(tournament)
    if tournament.tournament_plan
      "Gewählt: #{tournament.tournament_plan.name}"
    else
      count = tournament.seedings.where.not(state: "no_show").count
      "#{count} Spieler → Empfohlen: T#{count.to_s.rjust(2, '0')}"
    end
  end

  # Prüft ob Schritt aktivierbar ist
  def step_enabled?(tournament, step_number)
    wizard_step_status(tournament, step_number) == :active
  end
end

