# frozen_string_literal: true

# cc_start_party_day — Phase 47-03 (Thin-Bridge, User-Entscheid 2026-06-27).
# Öffnet den Spieltag (PartyMonitor) eines Pool-Mannschaftskampfs und liefert dem
# Sportwart/TL einen anklickbaren Carambus-Web-Link zum interaktiven Spielen/Werten.
# Muster wie cc_prepare_tournament: KEIN armed, idempotent, kein direkter CC-Touch.
# Das Live-Scoren passiert im Web — NICHT im Chat (vermeidet die 42-01-Intent-Falle).
#
# Auth: BaseTool#authorize_party_preparation! (46-01, keine neue Policy).
module McpServer
  module Tools
    class StartPartyDay < BaseTool
      tool_name "cc_start_party_day"
      description <<~DESC
        Wann nutzen? Wenn der Sportwart/Turnierleiter den Spieltag eines Mannschaftskampfs (Party) starten/öffnen will ("Starte den Spieltag", "Mach den Mannschaftskampf am Sonntag spielbereit", "Öffne den PartyMonitor").
        Was tippt der User typisch? "Starte den Spieltag von <Team> gegen <Team>", "Spieltag öffnen Liga X Spieltag 5".
        Party finden: party_id (aus cc_league_schedule / cc_my_teams) ODER league_id + day_seqno/date.
        Das Tool öffnet den PartyMonitor (find-or-create, lokal) und gibt einen anklickbaren Web-Link zurück — dort werden die Partien wie gewohnt im Web gespielt und gewertet. KEIN armed-Flag (idempotent, nicht destruktiv). Die Aufstellung setzt man vorher mit cc_set_party_lineup; den Stand fragt man mit cc_party_status ab.
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

        result = PartyPreparation::Opener.call(party: party)

        case result[:reason]
        when :party_invalid
          return error("Die Party konnte nicht aufgelöst werden.")
        when :not_local_server
          payload = {
            ok: false,
            reason: "not_local_server",
            party_name: result[:party_name],
            web_url: result[:web_url],
            message: "Spieltage werden auf dem lokalen Carambus-Server gestartet. Öffne den Spieltag im Web: #{result[:web_url]}"
          }
          return text(JSON.generate(payload))
        when :open_failed
          payload = {
            ok: false,
            reason: "open_failed",
            party_name: result[:party_name],
            web_url: result[:web_url],
            message: "Der Spieltag ließ sich nicht automatisch öffnen — versuch es über den Web-Link: #{result[:web_url]}"
          }
          write_audit(server_context, party, result, success: false)
          return text(JSON.generate(payload))
        end

        status = result[:status] || {}
        payload = {
          ok: true,
          party_name: result[:party_name],
          party_monitor_state: status[:party_monitor_state],
          web_url: result[:web_url],
          message: build_success_message(status, result[:web_url]),
          source: source_label(server_context, :db_mirror)
        }
        write_audit(server_context, party, result, success: true)
        text(JSON.generate(payload))
      rescue => e
        Rails.logger.warn "[StartPartyDay.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end

      def self.build_success_message(status, url)
        a = status[:seedings_a].to_i
        b = status[:seedings_b].to_i
        if a.zero? && b.zero?
          "Spieltag geöffnet — es ist aber noch keine Aufstellung gesetzt. Setze sie mit cc_set_party_lineup " \
            "oder direkt im Web. Gespielt und gewertet wird im Web: #{url}"
        else
          "Spieltag geöffnet (Aufstellung Heim #{a} / Gast #{b}). Spiele und werte die Partien im Web: #{url}"
        end
      end

      def self.write_audit(server_context, party, result, success:)
        operator_id = server_context&.dig(:user_id)
        McpServer::AuditTrail.write_entry(
          tool_name: "cc_start_party_day",
          operator: User.find_by(id: operator_id)&.email || "unknown",
          payload: {
            party_id: party.id,
            party_cc_id: party.try(:cc_id),
            opened: result[:ok]
          },
          pre_validation_results: [],
          read_back_status: result[:status]&.[](:party_monitor_state).to_s,
          result: success ? "success" : "failure",
          user_id: operator_id
        )
      rescue => e
        Rails.logger.warn "[StartPartyDay.write_audit] #{e.class}: #{e.message}"
      end
    end
  end
end
