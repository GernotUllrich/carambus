# frozen_string_literal: true

module ExternalTournament
  # Plan 16-01 (D-16-GC-A): Teardown/GC fuer lokale App-Turniere. Carambus haelt KEIN
  # Gedaechtnis der App-Turnierdaten — die App hat ihr eigenes Ergebnis-Gedaechtnis
  # (acknowledge_result live), daher darf Carambus nach dem Lebenszyklus abraeumen.
  #
  # Zwei Ausloeser (D-16-GC-A, Option D):
  #   - App-getrieben  → POST /api/external_tournament/end_tournament mit cleanup:true (opt-in)
  #   - Mitternachts-GC → rake external_tournament:release_stale_local_tables (Safety-Net)
  #
  # Geloescht werden ausschliesslich lokale App-Turniere (id >= MIN_ID + manual_assignment,
  # gleiches Kriterium wie TableReleaser#local_app_tournament?). Managed/globale Turniere und
  # fremde Games bleiben unberuehrt.
  #
  # Die App-Spiele tragen KEINEN tournament_id-FK (start_game/StartGameProcessor; kein Eintrag
  # in tournament.games), darum kaskadiert tournament.destroy sie NICHT — sie werden separat
  # ueber den durablen Marker game.data["tournament_external_id"] enumeriert und geloescht
  # (exakt das ResultCsvBuilder#games-Pattern). GameParticipations folgen via
  # Game#has_many(dependent: :destroy), gebundene TableMonitors via has_one(dependent: :nullify).
  class AppTournamentCleaner
    def self.cleanup(tournament)
      new.cleanup(tournament)
    end

    def self.sweep_closed_local
      new.sweep_closed_local
    end

    # Raeumt EIN lokales App-Turnier ab: zuerst dessen Marker-Games (+GameParticipation via
    # dependent:destroy), dann das Tournament selbst (kaskadiert TournamentMonitor/tournament_local/
    # seedings/teams/setting via Tournament-has_one/has_many dependent:destroy).
    # No-op (0/false) fuer nicht-lokale/managed Turniere und idempotent (2. Aufruf: Turnier weg).
    # @return [Hash] {games_deleted: Integer, tournament_deleted: Boolean}
    def cleanup(tournament)
      return result(0, false) unless local_app_tournament?(tournament)
      # Idempotenz: nach dem ersten Teardown ist das Turnier weg (in-memory destroyed bzw.
      # nicht mehr in der DB) → no-op statt erneutem destroy.
      return result(0, false) if tournament.destroyed?
      return result(0, false) unless Tournament.exists?(id: tournament.id)

      games = marker_games(tournament)
      games_deleted = games.size
      games.each(&:destroy)
      tournament.destroy
      result(games_deleted, true)
    end

    # Mitternachts-GC: raeumt alle ABGESCHLOSSENEN lokalen App-Turniere ab (TournamentMonitor
    # closed oder fehlend). Laeuft NACH TableReleaser.release_stale_local (das haengende Turniere
    # erst schliesst). Nicht-abgeschlossene (Monitor aktiv) + managed/globale bleiben unberuehrt.
    # Idempotent.
    # @return [Hash] {tournaments_deleted: Integer, games_deleted: Integer}
    def sweep_closed_local
      tournaments_deleted = 0
      games_deleted = 0
      closed_local_app_tournaments.each do |t|
        r = cleanup(t)
        next unless r[:tournament_deleted]
        tournaments_deleted += 1
        games_deleted += r[:games_deleted]
      end
      {tournaments_deleted: tournaments_deleted, games_deleted: games_deleted}
    end

    private

    def result(games_deleted, tournament_deleted)
      {games_deleted: games_deleted, tournament_deleted: tournament_deleted}
    end

    # Gleiches Kriterium wie TableReleaser#local_app_tournament?: lokal (id >= MIN_ID) + App
    # (manual_assignment). So bleiben managed/globale Turniere garantiert ausgeschlossen.
    def local_app_tournament?(t)
      t.present? && t.id.to_i >= ApplicationRecord::MIN_ID && t.manual_assignment?
    end

    # Marker-Games des Turniers: coarse SQL-LIKE-Vorfilter auf den external_id-String
    # (game.data ist serialized-JSON-Text → LIKE greift), danach exakter Marker-Abgleich in Ruby.
    # Kein ba_results-Filter (anders als ResultCsvBuilder#games): auch unbeendete App-Spiele
    # tragen den Marker und sollen mit abgeraeumt werden.
    def marker_games(tournament)
      ext = tournament.external_id.to_s
      return [] if ext.blank?
      Game.where("data LIKE ?", "%#{ext}%")
        .select { |g| safe_data(g)["tournament_external_id"].to_s == ext }
    end

    # Lokale App-Turniere mit abgeschlossenem (oder fehlendem) TournamentMonitor.
    def closed_local_app_tournaments
      Tournament.where("id >= ?", ApplicationRecord::MIN_ID)
        .where(manual_assignment: true)
        .select do |t|
          tm = t.tournament_monitor
          tm.nil? || tm.state == "closed"
        end
    end

    # game.data ist serialized JSON (Game-Model serialize :data) — defensiv (analog ResultCsvBuilder).
    def safe_data(record)
      d = record.data
      return d if d.is_a?(Hash)
      return {} if d.blank?
      JSON.parse(d.to_s)
    rescue JSON::ParserError
      {}
    end
  end
end
