# frozen_string_literal: true

module TournamentWizardHelper
  # Bestimmt den aktuellen Wizard-Schritt basierend auf Tournament State
  def wizard_current_step(tournament)
    case tournament.state
    when "new_tournament"
      # Schritt 1: Meldeliste laden (ClubCloud-Seedings vorhanden?)
      has_clubcloud_seedings = tournament.seedings.where("seedings.id < #{Seeding::MIN_ID}").exists?
      return 1 unless has_clubcloud_seedings
      
      # Schritt 2: Setzliste übernehmen (Lokale Seedings vorhanden?)
      has_local_seedings = tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").exists?
      return 2 unless has_local_seedings
      
      # Schritt 3: Teilnehmerliste bearbeiten
      3
    when "accreditation_finished"
      4 # Teilnehmerliste finalisieren
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

    # Spezialfall: Schritt 3 und 4 sind parallel aktiv
    # Schritt 3 = Bearbeiten, Schritt 4 = Finalisieren
    if current == 3 && step_number == 4
      :active  # Finalisieren-Button ist verfügbar während Schritt 3 aktiv ist
    elsif step_number < current
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
      if sync_needed?(tournament)
        "⚠️ Zuletzt: #{time_ago_in_words(tournament.sync_date)} her (vor Meldeschluss)"
      else
        "✓ Zuletzt: #{time_ago_in_words(tournament.sync_date)} her"
      end
    else
      "Noch nicht synchronisiert"
    end
  end
  
  # Prüft ob Synchronisierung notwendig ist
  def sync_needed?(tournament)
    return false unless tournament.accredation_end.present?
    return false unless tournament.sync_date.present?
    
    # Sync ist nötig, wenn letzte Sync VOR dem Meldeschluss war
    tournament.sync_date < tournament.accredation_end
  end
  
  # Sync-Status für Badge
  def sync_status_badge(tournament)
    if !tournament.sync_date
      { text: "Empfohlen", class: "badge-warning" }
    elsif sync_needed?(tournament)
      { text: "Empfohlen", class: "badge-warning" }
    else
      { text: "Optional", class: "badge-info" }
    end
  end

  # Spieleranzahl-Info
  def seedings_info_text(tournament)
    active_count = participant_count(tournament)
    "#{active_count} Spieler"
  end

  # Turniermodus-Info
  def mode_info_text(tournament)
    if tournament.tournament_plan
      "Gewählt: #{tournament.tournament_plan.name}"
    elsif tournament.data['extracted_plan_info'].present?
      # Zeige extrahierte Plan-Info aus Einladung (z.B. "T21 - 3 Gruppen à 3, 4 und 4 Spieler")
      count = participant_count(tournament)
      info = tournament.data['extracted_plan_info']
      "#{count} Teilnehmer → #{info}"
    else
      count = participant_count(tournament)
      "#{count} Spieler"
    end
  end
  
  # Intelligente Spielerzahl: Zählt entweder lokale ODER ClubCloud Seedings
  # Verhindert Doppelzählung bei parallelen Seeding-Sets
  def participant_count(tournament)
    has_local_seedings = tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").any?
    seeding_scope = has_local_seedings ? 
                      "seedings.id >= #{Seeding::MIN_ID}" : 
                      "seedings.id < #{Seeding::MIN_ID}"
    
    tournament.seedings
              .where.not(state: "no_show")
              .where(seeding_scope)
              .count
  end

  # Prüft ob Schritt aktivierbar ist
  def step_enabled?(tournament, step_number)
    wizard_step_status(tournament, step_number) == :active
  end
end

