# frozen_string_literal: true

# cc_lookup_tournament — DB-first Tournament lookup via TournamentCc mirror (D-02); live showMeisterschaft fallback.

module McpServer
  module Tools
    class LookupTournament < BaseTool
      tool_name "cc_lookup_tournament"
      description "Look up a ClubCloud tournament by CC meisterschaft ID or Carambus tournament ID. " \
                  "Queries the local Carambus DB (TournamentCc mirror) by default; pass force_refresh=true for live CC. " \
                  "Output enthält Detail-Felder (location_text, tournament_start, tournament_end, accredation_end). " \
                  "Mit `with_committed_list:true` wird zusätzlich showCommittedMeldeliste live abgefragt und " \
                  "die bereits angemeldeten Player-cc_ids aus dem HTML extrahiert (read-only). " \
                  "Konversations-UX: Vor JEDER Neuanmeldung die Liste der bereits angemeldeten Spieler kurz " \
                  "aufzählen — der TM erkennt so Doppelanmeldungen vor dem register-Tool. Tool ist DB-first; " \
                  "bei Detail-Lücken (fehlende location_text, fehlender tournament_start) `force_refresh:true` " \
                  "empfehlen — der CC-Sync ist max ~2h alt, aber Detail-Felder sind nicht immer komplett " \
                  "in den TournamentCc-Mirror gespiegelt."
      input_schema(
        properties: {
          meisterschaft_id: {type: "integer", description: "CC meisterschaft ID (cc_id on TournamentCc)"},
          tournament_id: {type: "integer", description: "Carambus-internal Tournament ID"},
          fed_id: {type: "integer", description: "ClubCloud federation ID (required for live lookup). Optional — resolved via region lookup (CC_REGION/Setting 'context', default 'NBV'); ENV CC_FED_ID overrides."},
          season: {type: "string", description: "Season name like '2025/2026'"},
          force_refresh: {type: "boolean", default: false, description: "Bypass DB cache, query CC live"},
          with_committed_list: {type: "boolean", default: false, description: "Wenn true, ruft showCommittedMeldeliste auf und liefert die bereits angemeldeten Player-cc_ids als 'committed_players' (read-only). meldeliste_cc_id wird aus TournamentCc.registration_list_cc abgeleitet — falls nicht in DB verknüpft, kann optional `meldeliste_cc_id` als Override gesetzt werden."},
          meldeliste_cc_id: {type: "integer", description: "Override für with_committed_list — nur nötig wenn TournamentCc keine registration_list_cc-Beziehung hat. Sonst wird der Wert aus der DB-Beziehung gelesen."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(meisterschaft_id: nil, tournament_id: nil, fed_id: nil, season: nil, force_refresh: false, with_committed_list: false, meldeliste_cc_id: nil, server_context: nil)
        fed_id ||= default_fed_id
        unless meisterschaft_id.present? || tournament_id.present?
          return error("Missing required parameter: provide `meisterschaft_id` or `tournament_id`")
        end

        return live_lookup(meisterschaft_id: meisterschaft_id, fed_id: fed_id, season: season) if force_refresh

        tournament_cc = if meisterschaft_id.present?
          TournamentCc.find_by(cc_id: meisterschaft_id)
        else
          TournamentCc.find_by(tournament_id: tournament_id)
        end

        return error("Tournament not found in Carambus DB. Try force_refresh: true to query CC.") if tournament_cc.nil?

        text(format_tournament_cc(tournament_cc, with_committed_list: with_committed_list, meldeliste_cc_id_override: meldeliste_cc_id, fed_id: fed_id))
      end

      def self.live_lookup(meisterschaft_id:, fed_id:, season:)
        return error("Missing meisterschaft_id for live lookup") if meisterschaft_id.blank?
        return error("Missing fed_id for live lookup") if fed_id.blank?
        client = cc_session.client_for
        params = {fedId: fed_id, meisterschaftId: meisterschaft_id}
        params[:season] = season if season.present?
        res, _doc = client.get("showMeisterschaft", params, {session_id: cc_session.cookie})
        return error("CC live-lookup failed: HTTP #{res&.code}") if res&.code != "200"
        text("CC live response for showMeisterschaft (meisterschaft_id=#{meisterschaft_id}, status #{res.code})")
      end

      def self.format_tournament_cc(tournament_cc, with_committed_list: false, meldeliste_cc_id_override: nil, fed_id: nil)
        tournament = tournament_cc.tournament
        meta = {}

        payload = {
          id: tournament_cc.id,
          cc_id: tournament_cc.cc_id,
          name: tournament_cc.name,
          status: tournament_cc.status,
          season: tournament_cc.season,
          tournament_id: tournament_cc.tournament_id,
          context: tournament_cc.context,
          location_text: tournament_cc.location_text,
          tournament_start: tournament_cc.tournament_start&.iso8601,
          tournament_end: tournament_cc.tournament_end&.iso8601,
          accredation_end: tournament&.accredation_end&.iso8601
        }

        if with_committed_list
          committed = read_committed_players(
            tournament_cc: tournament_cc,
            meldeliste_cc_id_override: meldeliste_cc_id_override,
            fed_id: fed_id,
            meta: meta
          )
          payload[:committed_players] = committed
        end

        payload[:meta] = meta unless meta.empty?
        JSON.generate(payload)
      end

      # Liest bereits-angemeldete Player-cc_ids via showCommittedMeldeliste.
      # Defensives Pattern (analog Phase-2 force_refresh): Sync-/Parse-Fehler erzeugen
      # nil + meta-Warnung statt Exception. meldeliste_cc_id-Auflösung primär aus
      # tournament_cc.registration_list_cc; Override-Param erlaubt Fallback.
      def self.read_committed_players(tournament_cc:, meldeliste_cc_id_override:, fed_id:, meta:)
        meldeliste_cc_id = meldeliste_cc_id_override.presence || tournament_cc.registration_list_cc&.cc_id
        if meldeliste_cc_id.blank?
          meta[:committed_list_warning] = "No registration_list_cc linked in TournamentCc — pass meldeliste_cc_id explicitly to read committed list."
          return nil
        end

        # 8-Felder-Payload analog Phase-5-D3-Bugfix in cc_register_for_tournament.
        # branchId aus tournament_cc.branch_cc.cc_id; clubId/disciplinId/catId als
        # Wildcards (CC akzeptiert "*" in show-Pfaden — analog register-Tool).
        branch_id = tournament_cc.branch_cc&.cc_id
        payload = {
          clubId: "*",
          fedId: fed_id,
          branchId: branch_id || "*",
          disciplinId: "*",
          catId: "*",
          season: tournament_cc.season,
          meldelisteId: meldeliste_cc_id,
          sortOrder: "player"
        }

        client = cc_session.client_for
        res, _doc = client.post("showCommittedMeldeliste", payload, {session_id: cc_session.cookie})

        if res.nil? || res.code != "200"
          meta[:committed_list_warning] = "showCommittedMeldeliste returned HTTP #{res&.code || "nil"} — committed_players unavailable."
          return nil
        end

        # Player-cc_id-Marker analog SNIFF v2 A2: <td align="center">{cc_id}</td>
        cc_ids = res.body.to_s.scan(%r{<td align="center">(\d+)</td>}).flatten.map(&:to_i).uniq
        cc_ids.map { |cc_id| {cc_id: cc_id} }
      rescue => e
        Rails.logger.warn "[cc_lookup_tournament] read_committed_players failed: #{e.class}: #{e.message}"
        meta[:committed_list_warning] = "Exception while reading committed list: #{e.class.name} (defensive — see Rails.logger)."
        nil
      end
    end
  end
end
