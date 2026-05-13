# frozen_string_literal: true

# cc_lookup_teilnehmerliste — D-18 acceptance-story read pathway; DB-first (D-02).
# Given a Carambus tournament_id or CC meldeliste_id, returns whether the Meldeliste
# exists in CC plus its finalization status. Live-fallback: showMeldelistenList.

module McpServer
  module Tools
    class LookupTeilnehmerliste < BaseTool
      tool_name "cc_lookup_teilnehmerliste"
      description "Wann nutzen? Vor Akkreditierung/Finalisierung — Turnierleiter will den aktuellen Stand der Teilnehmerliste sehen ('wer ist schon akkreditiert?'). Auch um den finalisiert-Status zu prüfen. " \
                  "Was tippt der User typisch? 'Liste zeigen', 'Wer ist akkreditiert für die Eurokegel?', 'Status Teilnehmerliste'. " \
                  "Look up the Teilnehmerliste (participant list / Meldeliste) for a tournament in ClubCloud. " \
                  "D-18 acceptance-story read pathway: given a Carambus tournament_id (or CC meldeliste_id + fed_id), " \
                  "returns whether the Meldeliste exists in CC and its finalization status. " \
                  "Queries the Carambus DB first (TournamentCc.registration_list_cc_id mirror); pass force_refresh=true for live CC."
      input_schema(
        properties: {
          tournament_id: {type: "integer", description: "Carambus-internal Tournament ID"},
          meldeliste_id: {type: "integer", description: "CC meldelisteId (RegistrationListCc.cc_id)"},
          fed_id: {type: "integer", description: "ClubCloud federation ID (required for live lookup). Optional — resolved via region lookup (CC_REGION/Setting 'context', default 'NBV'); ENV CC_FED_ID overrides."},
          force_refresh: {type: "boolean", default: false, description: "Bypass DB cache, query CC live"}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(tournament_id: nil, meldeliste_id: nil, fed_id: nil, force_refresh: false, server_context: nil)
        fed_id ||= default_fed_id
        unless tournament_id.present? || meldeliste_id.present?
          return error("Missing required parameter: provide `tournament_id` or `meldeliste_id`")
        end

        return live_lookup(fed_id: fed_id, meldeliste_id: meldeliste_id) if force_refresh

        # DB-first: look up Tournament → TournamentCc → RegistrationListCc mirror
        tournament_cc = if tournament_id.present?
          TournamentCc.find_by(tournament_id: tournament_id)
        else
          # meldeliste_id given — look for a TournamentCc with this registration_list_cc_id
          registration_cc = RegistrationListCc.find_by(cc_id: meldeliste_id) if defined?(RegistrationListCc)
          registration_cc&.tournament_cc
        end

        if tournament_id.present? && tournament_cc.nil?
          # Check if the Tournament itself exists before returning "not found in CC"
          tournament = Tournament.find_by(id: tournament_id)
          return error("Tournament #{tournament_id} not found in Carambus DB") unless tournament
          return text(JSON.generate(
            tournament_id: tournament_id,
            tournament_title: tournament.title,
            cc_tournament_id: nil,
            meldeliste_cc_id: nil,
            status: "no_cc_mirror",
            message: "Tournament exists in Carambus but has no TournamentCc mirror. " \
                     "Use force_refresh: true with fed_id to check CC directly."
          ))
        end

        return error("Teilnehmerliste not found in Carambus DB. Try force_refresh: true to query CC.") if tournament_cc.nil?

        text(format_teilnehmerliste(tournament_cc))
      end

      def self.live_lookup(fed_id:, meldeliste_id:)
        return error("Missing fed_id for live Teilnehmerliste lookup") if fed_id.blank?
        client = cc_session.client_for(server_context)
        res, _doc = client.get("showMeldelistenList", {fedId: fed_id}, {session_id: cc_session.cookie})
        return error("CC live-lookup failed: HTTP #{res&.code}") if res&.code != "200"
        found = meldeliste_id.present? ? " (looking for meldeliste_id=#{meldeliste_id})" : ""
        text("CC live response for showMeldelistenList#{found} (fed_id=#{fed_id}, status #{res.code})")
      end

      def self.format_teilnehmerliste(tournament_cc)
        JSON.generate(
          cc_tournament_id: tournament_cc.cc_id,
          tournament_id: tournament_cc.tournament_id,
          name: tournament_cc.name,
          status: tournament_cc.status,
          season: tournament_cc.season,
          meldeliste_cc_id: tournament_cc.registration_list_cc_id,
          context: tournament_cc.context
        )
      end
    end
  end
end
