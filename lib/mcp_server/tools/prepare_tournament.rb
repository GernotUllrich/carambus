# frozen_string_literal: true

# cc_prepare_tournament — Phase 42 Spike (2026-06-16 Re-Plan).
# Bereitet ein Carambus-Turnier für den Spielbetrieb vor:
#   - synct die aktuelle Teilnehmerliste über den OFFIZIELLEN Pfad
#     `Version.update_from_carambus_api(update_tournament_from_cc:)` —
#     KEIN eigener CC-Touch (User-Direktive).
#     [[project_version_update_object_scoped_rescrape]]
#   - liefert dem Sportwart einen Markdown-fähigen Link zur Carambus-Web-
#     Turniervorbereitung (`finalize_modus_tournament_url`), wo Modus +
#     Setzliste + Tische gewählt werden und der TurnierMonitor gestartet wird.
#
# NICHT destruktiv. KEIN `armed`-Flag. Idempotent — Re-Aufrufe applizieren nur
# neue Versions-Records.
#
# Auth: TournamentPolicy#prepare_tournament? (admin || leiter? || in_sportwart_scope?).
module McpServer
  module Tools
    class PrepareTournament < BaseTool
      tool_name "cc_prepare_tournament"
      description <<~DESC
        Wann nutzen? Wenn der Sportwart oder Turnierleiter ein Carambus-Turnier für den Spielbetrieb vorbereiten will ("Bereite das Cadre-Turnier vor", "Mach das DM Cadre spielfertig").
        Was tippt der User typisch? "Bereite das Cadre-Turnier vor", "Cadre 35/2 spielbereit machen", "Vorbereitung DM Cadre".
        Das Tool holt die aktuelle Teilnehmerliste über den offiziellen Sync-Pfad in die Carambus-Datenbank und gibt einen anklickbaren Link zur Carambus-Turniervorbereitung zurück — dort wählt der Sportwart Modus + Setzliste + Tische und startet den TurnierMonitor wie gewohnt im Web.
        Aufruf über tournament_cc_id (ClubCloud-ID). KEIN armed-Flag — der Aufruf ist idempotent und nicht destruktiv.
        Autorisiert für system_admin, Sportwart-im-Wirkbereich und Turnierleiter des Turniers.
      DESC
      input_schema(
        properties: {
          tournament_cc_id: {type: "integer", description: "Pflicht. ClubCloud-ID des Turniers (tournament_cc.cc_id)."}
        },
        required: ["tournament_cc_id"]
      )
      annotations(read_only_hint: false, destructive_hint: false)

      def self.call(tournament_cc_id: nil, server_context: nil)
        err = validate_required!({tournament_cc_id: tournament_cc_id}, [:tournament_cc_id])
        return err if err

        tournament = resolve_tournament(tournament_cc_id: tournament_cc_id, server_context: server_context)
        return error("Turnier zu dieser Kennung nicht gefunden (in dieser Region).") if tournament.nil?

        auth_err = authorize!(action: :prepare_tournament, tournament: tournament, server_context: server_context)
        return auth_err if auth_err

        result = TournamentPreparation::Opener.call(tournament: tournament)

        # Edge-Cases jargonfrei zurückgeben.
        case result[:reason]
        when :tournament_invalid
          return error("Das Turnier hat keine ClubCloud-Verknüpfung — eine Vorbereitung über den Sync ist nicht möglich.")
        when :no_authority_configured
          payload = {
            ok: false,
            reason: "no_authority_configured",
            tournament_name: result[:tournament_name],
            preparation_url: result[:preparation_url],
            message: "Dieser Server ist die Authority und kann sich nicht selbst synchronisieren. " \
                     "Die Turniervorbereitung ist trotzdem erreichbar: #{result[:preparation_url]}"
          }
          return text(JSON.generate(payload))
        when :sync_failed
          payload = {
            ok: false,
            reason: "sync_failed",
            tournament_name: result[:tournament_name],
            preparation_url: result[:preparation_url],
            message: "Der Sync mit der zentralen Carambus-Datenbank hat nicht geklappt — " \
                     "versuche es gleich noch einmal. Die Turniervorbereitung kannst du trotzdem " \
                     "öffnen: #{result[:preparation_url]}"
          }
          write_audit(server_context, tournament_cc_id, tournament, result, success: false)
          return text(JSON.generate(payload))
        end

        # Erfolgsfall: Status + Message in Sportwart-Sprache.
        status = result[:status] || {}
        message = build_success_message(status, result[:preparation_url])

        payload = {
          ok: true,
          tournament_name: result[:tournament_name],
          status: status,
          preparation_url: result[:preparation_url],
          message: message,
          source: source_label(server_context, :db_mirror)
        }

        write_audit(server_context, tournament_cc_id, tournament, result, success: true)
        text(JSON.generate(payload))
      rescue => e
        Rails.logger.warn "[PrepareTournament.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end

      # DEV-42-NEU-B (Live-Test 2026-06-16): Nächster Schritt ist immer das
      # Finalisieren der Setzliste auf der Turnier-Show-Seite (aus Einladung ODER
      # durch Bearbeiten der Teilnehmerliste) — NICHT direkt die Modus-Auswahl.
      def self.build_success_message(status, url)
        has_seeding = status[:seedings_count].to_i > 0
        if status[:plan_chosen] && has_seeding
          "Die Teilnehmer sind synchronisiert und eine Setzliste liegt vor. Öffne die " \
            "Turniervorbereitung, prüfe die Setzliste und starte dann den TurnierMonitor: #{url}"
        else
          "Die Teilnehmer sind synchronisiert (#{status[:seedings_count]} Spieler). Öffne die " \
            "Turniervorbereitung und finalisiere zuerst die Setzliste — aus der Einladung oder " \
            "durch Bearbeiten der Teilnehmerliste. Danach folgen Modus-Auswahl und " \
            "TurnierMonitor-Start: #{url}"
        end
      end

      def self.write_audit(server_context, tournament_cc_id, tournament, result, success:)
        operator_id = server_context&.dig(:user_id)
        McpServer::AuditTrail.write_entry(
          tool_name: "cc_prepare_tournament",
          operator: User.find_by(id: operator_id)&.email || "unknown",
          payload: {
            tournament_id: tournament.id,
            tournament_cc_id: tournament_cc_id,
            sync_ok: result[:ok]
          },
          pre_validation_results: [],
          read_back_status: result[:status]&.[](:tournament_state).to_s,
          result: success ? "success" : "failure",
          user_id: operator_id
        )
      rescue => e
        Rails.logger.warn "[PrepareTournament.write_audit] #{e.class}: #{e.message}"
      end
    end
  end
end
