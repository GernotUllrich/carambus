# frozen_string_literal: true

# cc_open_in_tournament_app — Phase 43 (Path-B-Spike, Chat-Brücke zu carambus_app).
# Beseitigt die Verbindungs-Reibung zur externen Turnier-App:
#   - synct die Teilnehmerliste über den offiziellen Pfad (TournamentPreparation::Opener,
#     Phase 42 → Version.update_from_carambus_api), damit der bestehende
#     external_tournament/seeding-Endpoint frische Spieler liefert.
#   - liefert einen vorverbindenden App-Deep-Link (TournamentPreparation::AppLinkBuilder).
#
# Die App ist autark (D-43-2): generiert ihr EIGENES Turnier (eigener Plan), nimmt von
# Carambus NUR die Teilnehmerliste. KEIN tournament_cc_id-Monitor-Anbinden, KEIN
# LocalTournamentCreator, KEIN TournamentMonitor.
#
# Idempotent, nicht-destruktiv, KEIN armed-Flag. Auth via prepare_tournament? (D-42-7
# wiederverwendet). Passwort wird NIE im Link übertragen (D-43-7).
module McpServer
  module Tools
    class OpenInTournamentApp < BaseTool
      tool_name "cc_open_in_tournament_app"
      description <<~DESC
        Wann nutzen? Wenn der Turnierleiter ein Turnier in der Carambus-Turnier-App (externe App) abwickeln will ("öffne das Cadre-Turnier in der Turnier-App", "Turnier-App für das DM Cadre vorbereiten").
        Was tippt der User typisch? "Öffne das Cadre-Turnier in der Turnier-App", "Turnier-App-Link für das Dreiband-Turnier".
        Das Tool holt die aktuelle Teilnehmerliste in die Carambus-Datenbank und gibt einen Link zurück, der die Turnier-App vorverbunden öffnet. Die App führt das Turnier eigenständig (eigener Spielplan) und zieht nur die Teilnehmer aus Carambus.
        Aufruf über tournament_cc_id (ClubCloud-ID). KEIN armed-Flag — idempotent und nicht destruktiv.
        Autorisiert für system_admin, Sportwart-im-Wirkbereich und Turnierleiter.
      DESC
      input_schema(
        properties: {
          tournament_cc_id: {type: "integer", description: "Pflicht. ClubCloud-ID des Turniers (tournament_cc.cc_id) als Teilnehmer-Quelle."}
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

        sync = TournamentPreparation::Opener.call(tournament: tournament)
        link_res = TournamentPreparation::AppLinkBuilder.call(tournament: tournament, server_context: server_context)

        unless link_res[:ok]
          return error("Der Link zur Turnier-App konnte nicht gebaut werden (#{link_res[:reason]}). Bitte die App-Adresse in der Server-Konfiguration prüfen.")
        end

        app_link = link_res[:app_link]
        participants = sync.dig(:status, :seedings_count)

        message =
          if sync[:ok]
            "Die Teilnehmerliste ist synchronisiert (#{participants} Spieler). Öffne das Turnier in der " \
              "Turnier-App über diesen Link — Verbindung ist vorausgefüllt, nur das App-Passwort fehlt noch: #{app_link}"
          else
            "Der Link zur Turnier-App ist bereit: #{app_link} — Hinweis: die Teilnehmerliste konnte gerade " \
              "nicht frisch abgeglichen werden, in der App siehst du ggf. einen etwas älteren Stand."
          end

        write_audit(server_context, tournament_cc_id, tournament, sync)

        payload = {
          ok: sync[:ok],
          tournament_name: sync[:tournament_name] || tournament.title,
          participants_count: participants,
          app_link: app_link,
          message: message,
          source: source_label(server_context, :db_mirror)
        }
        text(JSON.generate(payload))
      rescue => e
        Rails.logger.warn "[OpenInTournamentApp.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end

      def self.write_audit(server_context, tournament_cc_id, tournament, sync)
        operator_id = server_context&.dig(:user_id)
        McpServer::AuditTrail.write_entry(
          tool_name: "cc_open_in_tournament_app",
          operator: User.find_by(id: operator_id)&.email || "unknown",
          payload: {tournament_id: tournament.id, tournament_cc_id: tournament_cc_id, sync_ok: sync[:ok]},
          pre_validation_results: [],
          read_back_status: "n/a",
          result: sync[:ok] ? "success" : "failure",
          user_id: operator_id
        )
      rescue => e
        Rails.logger.warn "[OpenInTournamentApp.write_audit] #{e.class}: #{e.message}"
      end
    end
  end
end
