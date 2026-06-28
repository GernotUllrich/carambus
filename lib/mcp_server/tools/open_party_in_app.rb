# frozen_string_literal: true

# cc_open_party_in_app — Phase 48-05 (Instrumentierung, §6 Schema-Handoff). Chat-Brücke zu
# carambus_app für Liga-Spieltage: gibt einen vorverbindenden App-Deeplink auf das
# "spieltag"-Schema zurück (Verbindung + Party-Kontext vorausgefüllt). Die App fährt den
# Spieltag autark über die external_tournament/party*-Endpoints (Plan 48-04) — Ergebnisse
# direkt eingeben, ohne Scoreboard.
#
# Abgrenzung: cc_start_party_day öffnet den Carambus-WEB-PartyMonitor; cc_open_party_in_app
# öffnet die externe App. Idempotent, nicht-destruktiv, KEIN armed. Passwort NIE im Link (D-43-7).
# Auth: BaseTool#authorize_party_preparation! (46-01, keine neue Policy). Gespiegelt von
# cc_open_in_tournament_app (Phase 43) + cc_start_party_day (47-03).
module McpServer
  module Tools
    class OpenPartyInApp < BaseTool
      tool_name "cc_open_party_in_app"
      description <<~DESC
        Wann nutzen? Wenn der Sportwart/Turnierleiter den Spieltag eines Mannschaftskampfs (Party) in der externen Carambus-App (carambus_app, "spieltag"-Schema) abwickeln will ("öffne den Spieltag in der App", "Spieltag-App-Link für <Team> gegen <Team>").
        Was tippt der User typisch? "Öffne den Spieltag in der App", "App-Link für den Mannschaftskampf am Sonntag".
        Party finden: party_id (aus cc_league_schedule / cc_my_teams) ODER league_id + day_seqno/date.
        Das Tool gibt einen Deep-Link zurück, der die App vorverbunden mit dem Party-Kontext öffnet — dort wird der Spieltag eigenständig gefahren (Ergebnisse direkt eingeben, ohne Scoreboard). Verbindung ist vorausgefüllt, nur das App-Passwort fehlt noch. KEIN armed-Flag (idempotent, nicht destruktiv).
        Abgrenzung: cc_start_party_day öffnet stattdessen den Carambus-Web-PartyMonitor.
        Autorisiert für system_admin, Sportwart-im-Wirkbereich und Turnierleiter der Liga.
      DESC
      input_schema(
        properties: {
          party_id: {type: "integer", description: "Carambus party_id (aus cc_league_schedule / cc_my_teams) — eindeutigster Weg."},
          league_id: {type: "integer", description: "Alternativ zur party_id: Liga (aus cc_list_leagues) — mit day_seqno ODER date."},
          cc_id: {type: "integer", description: "Optional: ClubCloud league cc_id (statt league_id, mit day_seqno/date)."},
          day_seqno: {type: "integer", description: "Spieltag-Nummer (mit league_id/cc_id)."},
          date: {type: "string", description: "Datum YYYY-MM-DD (mit league_id/cc_id)."}
        }
      )
      annotations(read_only_hint: false, destructive_hint: false)

      def self.call(party_id: nil, league_id: nil, cc_id: nil, day_seqno: nil, date: nil, server_context: nil)
        resolved = resolve_party(server_context, party_id: party_id, league_id: league_id, cc_id: cc_id, day_seqno: day_seqno, date: date)
        return resolved[:error] if resolved[:error]
        party = resolved[:party]

        auth_err = authorize_party_preparation!(party: party, server_context: server_context)
        return auth_err if auth_err

        link_res = PartyPreparation::AppLinkBuilder.call(party: party, server_context: server_context)
        unless link_res[:ok]
          return error("Der Link zur Spieltag-App konnte nicht gebaut werden (#{link_res[:reason]}). Bitte die App-Adresse in der Server-Konfiguration prüfen.")
        end

        app_link = link_res[:app_link]
        payload = {
          ok: true,
          party_name: safe_party_name(party),
          party_cc_id: party.try(:cc_id),
          app_link: app_link,
          message: "Öffne den Spieltag in der App über diesen Link — Verbindung ist vorausgefüllt, " \
            "nur das App-Passwort fehlt noch: #{app_link}",
          source: source_label(server_context, :db_mirror)
        }
        write_audit(server_context, party, app_link)
        text(JSON.generate(payload))
      rescue => e
        Rails.logger.warn "[OpenPartyInApp.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end

      def self.safe_party_name(party)
        party.name
      rescue
        "Party #{party.id}"
      end

      def self.write_audit(server_context, party, app_link)
        operator_id = server_context&.dig(:user_id)
        McpServer::AuditTrail.write_entry(
          tool_name: "cc_open_party_in_app",
          operator: User.find_by(id: operator_id)&.email || "unknown",
          payload: {party_id: party.id, party_cc_id: party.try(:cc_id), app_link_built: app_link.present?},
          pre_validation_results: [],
          read_back_status: "n/a",
          result: "success",
          user_id: operator_id
        )
      rescue => e
        Rails.logger.warn "[OpenPartyInApp.write_audit] #{e.class}: #{e.message}"
      end
    end
  end
end
