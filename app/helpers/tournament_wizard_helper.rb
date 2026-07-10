# frozen_string_literal: true

module TournamentWizardHelper
  # Die sechs Wizard-Buckets (konsistent mit wizard_status_text); Anzeige-Text via
  # t("tournaments.wizard.bucket.<key>")
  WIZARD_BUCKETS = %i[preparation seeding_setup mode_selection ready_to_start running completed].freeze

  # Tailwind-Klasse für das dominante AASM-State-Badge im Wizard-Header (FIX-04)
  def wizard_state_badge_class(tournament)
    case tournament.state.to_s
    when "new_tournament" then "bg-orange-500 text-white"
    when "accreditation_finished",
         "tournament_seeding_finished" then "bg-blue-500 text-white"
    when "tournament_mode_defined" then "bg-indigo-500 text-white"
    when "tournament_started_waiting_for_monitors" then "bg-yellow-500 text-gray-900"
    when "tournament_started" then "bg-green-600 text-white"
    when "tournament_finished" then "bg-green-800 text-white"
    when "results_published" then "bg-gray-700 text-white"
    when "closed" then "bg-gray-500 text-white"
    else "bg-gray-400 text-white"
    end
  end

  # Übersetzter Text für das AASM-State-Badge (FIX-04)
  def wizard_state_badge_label(tournament)
    case tournament.state.to_s
    when "new_tournament" then t("tournaments.wizard.state_badge.new_tournament")
    when "accreditation_finished" then t("tournaments.wizard.state_badge.accreditation_finished")
    when "tournament_seeding_finished" then t("tournaments.wizard.state_badge.tournament_seeding_finished")
    when "tournament_mode_defined" then t("tournaments.wizard.state_badge.tournament_mode_defined")
    when "tournament_started_waiting_for_monitors" then t("tournaments.wizard.state_badge.tournament_started_waiting_for_monitors")
    when "tournament_started" then t("tournaments.wizard.state_badge.tournament_started")
    when "tournament_finished" then t("tournaments.wizard.state_badge.tournament_finished")
    when "results_published" then t("tournaments.wizard.state_badge.results_published")
    when "closed" then t("tournaments.wizard.state_badge.closed")
    else tournament.state.to_s.humanize
    end
  end

  # Liefert die sechs Bucket-Chips für den Wizard-Header (FIX-03)
  # Jeder Chip enthält :label (übersetzt) und :active (Boolean, Vergleich auf internem Symbol)
  def wizard_bucket_chips(tournament)
    current_key = wizard_status_text(tournament)
    WIZARD_BUCKETS.map { |key| {label: t("tournaments.wizard.bucket.#{key}"), active: key == current_key} }
  end

  # Bestimmt den aktuellen Wizard-Schritt basierend auf Tournament State
  def wizard_current_step(tournament)
    case tournament.state
    when "new_tournament"
      # Check for local seedings first (for manual/test entries)
      has_local_seedings = tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").exists?

      # If we have local seedings, we're at least at step 3 (editing participants)
      return 3 if has_local_seedings

      # Schritt 1: Meldeliste laden (ClubCloud-Seedings vorhanden?)
      has_clubcloud_seedings = tournament.seedings.where("seedings.id < #{Seeding::MIN_ID}").exists?
      return 1 unless has_clubcloud_seedings

      # Schritt 2: Setzliste übernehmen (ClubCloud vorhanden, aber noch nicht zu lokal konvertiert)
      2
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

  # Status-Key (internes Symbol, konsistent mit WIZARD_BUCKETS; Anzeige via
  # t("tournaments.wizard.bucket.<key>") in wizard_bucket_chips)
  def wizard_status_text(tournament)
    case wizard_current_step(tournament)
    when 1..2 then :preparation
    when 3..4 then :seeding_setup
    when 5 then :mode_selection
    when 6 then :ready_to_start
    when 7 then :running
    when 8 then :completed
    else :preparation
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
        t("tournaments.wizard.sync_info.overdue", time: time_ago_in_words(tournament.sync_date))
      else
        t("tournaments.wizard.sync_info.recent", time: time_ago_in_words(tournament.sync_date))
      end
    else
      t("tournaments.wizard.sync_info.never")
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
      {text: "Empfohlen", class: "badge-warning"}
    elsif sync_needed?(tournament)
      {text: "Empfohlen", class: "badge-warning"}
    else
      {text: "Optional", class: "badge-info"}
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
    elsif tournament.data["extracted_plan_info"].present?
      # Zeige extrahierte Plan-Info aus Einladung (z.B. "T21 - 3 Gruppen à 3, 4 und 4 Spieler")
      count = participant_count(tournament)
      info = tournament.data["extracted_plan_info"]
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
