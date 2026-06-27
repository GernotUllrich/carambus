# frozen_string_literal: true

# cc_party_status — Phase 47-03 (Thin-Bridge, Read). Berichtet den Stand eines
# Mannschaftskampf-Spieltags: ob gestartet, AASM-Zustand, aktuelles Mannschafts-
# ergebnis (Party#intermediate_result, 47-02) und „was als nächstes" in Klartext,
# plus Web-Link. Reine Lese-Antwort (kein armed, kein Öffnen/Erzeugen).
module McpServer
  module Tools
    class PartyStatus < BaseTool
      tool_name "cc_party_status"
      description <<~DESC
        Wann nutzen? Wenn jemand den Stand eines Mannschaftskampf-Spieltags wissen will ("Wie steht der Spieltag?", "Ist der Mannschaftskampf fertig?", "Was ist als nächstes zu tun?").
        Was tippt der User typisch? "Wie steht der Spieltag von <Team>?", "Ist Liga X Spieltag 5 abgeschlossen?".
        Party finden: party_id (aus cc_league_schedule / cc_my_teams) ODER league_id + day_seqno/date.
        Liefert Zustand, aktuelles Mannschaftsergebnis und einen Klartext-Hinweis, was als nächstes zu tun ist (das Spielen/Werten passiert im Web — Link inklusive). Reine Lese-Auskunft.
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
      annotations(read_only_hint: true)

      def self.call(party_id: nil, league_id: nil, cc_id: nil, day_seqno: nil, date: nil, server_context: nil)
        resolved = resolve_party(server_context, party_id: party_id, league_id: league_id, cc_id: cc_id, day_seqno: day_seqno, date: date)
        return resolved[:error] if resolved[:error]
        party = resolved[:party]

        pm = party.party_monitor
        result = pm&.data&.dig("result")
        payload = {
          party_name: party.name,
          started: pm.present?,
          state: pm&.state,
          intermediate_result: party.intermediate_result,
          result: result,
          next_step: next_step_for(pm, result),
          web_url: party_web_url(party),
          source: source_label(server_context, :db_mirror)
        }
        text(JSON.generate(payload))
      rescue => e
        Rails.logger.warn "[PartyStatus.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end

      def self.next_step_for(party_monitor, result)
        return "Noch nicht gestartet — mit cc_start_party_day öffnen." if party_monitor.nil?

        case party_monitor.state
        when "seeding_mode"
          "Aufstellung im Web bestätigen."
        when "table_definition_mode", "next_round_seeding_mode", "ready_for_next_round"
          "Runde im Web vorbereiten und starten."
        when "playing_round"
          "Runde läuft — Ergebnisse im Web erfassen."
        when "round_result_checking_mode"
          "Runde prüfen, dann nächste Runde oder Spieltag abschließen."
        when "party_result_checking_mode"
          "Spieltag abschließen."
        when "closed"
          gp = result && result["game_points"]
          gp.present? ? "Spieltag abgeschlossen (Ergebnis #{gp})." : "Spieltag abgeschlossen."
        else
          "Im Web fortfahren."
        end
      end

      def self.party_web_url(party)
        Rails.application.routes.url_helpers.party_monitor_party_url(party, host: web_host)
      rescue => e
        Rails.logger.warn "[PartyStatus.party_web_url] #{e.class}: #{e.message}"
        nil
      end

      def self.web_host
        Carambus.config.try(:carambus_domain).presence ||
          Rails.application.config.action_mailer&.default_url_options&.[](:host).presence ||
          "localhost:3007"
      end
    end
  end
end
