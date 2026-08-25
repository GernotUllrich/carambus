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
  # (coarse SQL-LIKE auf den external_id-String + exakter Marker-Abgleich). GameParticipations folgen via
  # Game#has_many(dependent: :destroy), gebundene TableMonitors via has_one(dependent: :nullify).
  class AppTournamentCleaner
    # Plan 41-01 (Nachtrag auf Rueckfrage von carambus_app, 2026-08-25):
    # Sagt aus, ob der AUTOMATISCHE Sweep archivierte Turniere (data["archived_at"]) verschont.
    #
    # Warum ueberhaupt: der Archiv-Endpoint meldet `archived: true`, sobald er geschrieben hat —
    # aber "geschrieben" ist nicht "haelt". Solange der naechtliche GC das Turnier weiterhin
    # loescht, waere es unehrlich, der App Dauerhaftigkeit zu melden; ihr Turnierleiter bekaeme
    # "archiviert" angezeigt fuer etwas, das am naechsten Morgen weg ist.
    #
    # Diese Konstante ist KEINE Pflegeangabe: `app_tournament_cleaner_archive_test.rb` koppelt
    # sie an das tatsaechliche Verhalten und faellt, wenn beide auseinanderlaufen — in BEIDE
    # Richtungen. Plan 41-02 setzt sie auf true und dreht die Testrichtung mit.
    ARCHIVE_AWARE = false

    def self.cleanup(tournament)
      new.cleanup(tournament)
    end

    def self.sweep_closed_local
      new.sweep_closed_local
    end

    # App-Spiele eines Turniers finden, ohne etwas abzuraeumen (reset_app_tournament-Task).
    def self.app_games(tournament)
      new.send(:marker_games, tournament)
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
    # Kein ba_results-Filter: auch unbeendete App-Spiele tragen den Marker und sollen
    # mit abgeraeumt werden.
    def marker_games(tournament)
      (via_tournament_marker(tournament) + via_attach_prefix(tournament)).uniq
    end

    # Klassischer Pfad: von LocalTournamentCreator angelegte App-Turniere tragen eine
    # external_id, die StartGameProcessor als tournament_external_id in game.data schreibt.
    def via_tournament_marker(tournament)
      ext = tournament.external_id.to_s
      return [] if ext.blank?
      Game.where("data LIKE ?", "%#{ext}%")
        .select { |g| safe_data(g)["tournament_external_id"].to_s == ext }
    end

    # HANDOFF reset-app-tournament-task (2026-08-19): Attach-Turniere werden im Web bzw. per
    # Console angelegt, NICHT ueber LocalTournamentCreator -> external_id ist nil, der Marker
    # oben findet nichts und die App-Games blieben beim cleanup als Waisen liegen. Der
    # Attach-Modus bildet die game-external_id deterministisch als "attach-<tournament_id>-<key>".
    def via_attach_prefix(tournament)
      prefix = "attach-#{tournament.id}-"
      Game.where("data LIKE ?", "%#{prefix}%")
        .select { |g| safe_data(g)["external_id"].to_s.start_with?(prefix) }
    end

    # Lokale App-Turniere mit abgeschlossenem (oder fehlendem) TournamentMonitor.
    def closed_local_app_tournaments
      Tournament.where("id >= ?", ApplicationRecord::MIN_ID)
        .where(manual_assignment: true)
        # HANDOFF multiday-app-tournaments (2026-08-19): Mehrtaegige Attach-Turniere deklarieren
        # ihre Laufzeit ueber end_date. Solange die laeuft, nicht abraeumen — der Mitternachts-GC
        # loeschte sonst am 2. Turniertag das Turnier samt aller erfassten Ergebnisse.
        # end_date nil oder vergangen -> unveraendertes Verhalten (Safety-Net bleibt intakt).
        # Nur der automatische Sweep; der explizite cleanup(t) aus end_tournament?cleanup=true
        # bleibt bewusst ungefiltert (ausdruecklicher Bedienwunsch).
        .where("end_date IS NULL OR end_date < ?", Time.current)
        .select do |t|
          tm = t.tournament_monitor
          tm.nil? || tm.state == "closed"
        end
    end

    # game.data ist serialized JSON (Game-Model serialize :data) — defensiv gegen Nicht-Hash/Parse-Fehler.
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
