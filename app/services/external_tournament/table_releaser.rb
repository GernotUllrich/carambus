# frozen_string_literal: true

module ExternalTournament
  # Plan 17-05 (Vision L/M/N): Lifecycle-Exit — gibt die an ein lokales App-Turnier
  # gebundenen Tische wieder frei. Drei Auslöser teilen diese Primitive:
  #   - App-Turnierende        → POST /api/external_tournament/end_tournament
  #   - Sysadmin-Fallback      → rake external_tournament:end[id]
  #   - Mitternachts-Abbruch   → rake external_tournament:release_stale_local_tables (whenever)
  #
  # Anders als der Operator (17-04) dürfen diese Pfade auch UNBESTÄTIGTE Ergebnisse
  # freigeben (D-17-vision-5) → reset_table_monitor(force: true) (force_ready! statt
  # close_match!, daher kein external_release_allowed?-Guard).
  class TableReleaser
    # release_tournament: pro Turnier
    TournamentResult = Struct.new(:released, :unacknowledged, :tournament_monitor_state, keyword_init: true)

    def self.release_tournament(tournament)
      new.release_tournament(tournament)
    end

    def self.release_stale_local
      new.release_stale_local
    end

    # Gibt alle an das Turnier (dessen TournamentMonitor) gebundenen Tische frei und
    # schließt den TournamentMonitor. Idempotent (2. Aufruf: keine Bindungen mehr → released 0).
    def release_tournament(tournament)
      owner = tournament&.tournament_monitor
      return TournamentResult.new(released: 0, unacknowledged: 0, tournament_monitor_state: owner&.state) if owner.blank?

      released = 0
      unacknowledged = 0
      bound_table_monitors(owner).each do |tm|
        unacknowledged += 1 if tm.external_result_pending?
        tm.reset_table_monitor(force: true)
        released += 1
      end
      owner.end_of_tournament! if owner.may_end_of_tournament?
      TournamentResult.new(released: released, unacknowledged: unacknowledged, tournament_monitor_state: owner.reload.state)
    end

    # Mitternachts-Safety-Net: gibt alle Bindungen lokaler App-Turniere
    # (id >= MIN_ID + manual_assignment) frei + schließt deren TournamentMonitor.
    # Managed/nicht-lokale Turniere bleiben unberührt. Idempotent.
    def release_stale_local
      released = 0
      tournaments_closed = 0
      stale_owners.each do |owner|
        bound = bound_table_monitors(owner)
        next if bound.empty?
        bound.each do |tm|
          tm.reset_table_monitor(force: true)
          released += 1
        end
        if owner.may_end_of_tournament?
          owner.end_of_tournament!
          tournaments_closed += 1
        end
      end
      {released: released, tournaments_closed: tournaments_closed}
    end

    private

    def bound_table_monitors(owner)
      TableMonitor.where(tournament_monitor_id: owner.id, tournament_monitor_type: "TournamentMonitor").to_a
    end

    # TournamentMonitors mit gebundenen Tischen, nicht closed, deren Tournament lokal
    # (id >= MIN_ID) UND manual_assignment ist (= App-Turnier).
    def stale_owners
      owner_ids = TableMonitor
        .where(tournament_monitor_type: "TournamentMonitor")
        .where.not(tournament_monitor_id: nil)
        .distinct.pluck(:tournament_monitor_id)
      TournamentMonitor.where(id: owner_ids).where.not(state: "closed")
        .select { |owner| local_app_tournament?(owner.tournament) }
    end

    def local_app_tournament?(t)
      t.present? && t.id.to_i >= ApplicationRecord::MIN_ID && t.manual_assignment?
    end
  end
end
