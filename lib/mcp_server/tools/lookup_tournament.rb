# frozen_string_literal: true
# cc_lookup_tournament — DB-first Tournament lookup via TournamentCc mirror (D-02); live showMeisterschaft fallback.

module McpServer
  module Tools
    class LookupTournament < BaseTool
      tool_name "cc_lookup_tournament"
      description "Look up a ClubCloud tournament by CC meisterschaft ID or Carambus tournament ID. " \
                  "Queries the local Carambus DB (TournamentCc mirror) by default; pass force_refresh=true for live CC."
      input_schema(
        properties: {
          meisterschaft_id: { type: "integer", description: "CC meisterschaft ID (cc_id on TournamentCc)" },
          tournament_id:    { type: "integer", description: "Carambus-internal Tournament ID" },
          fed_id:           { type: "integer", description: "ClubCloud federation ID (required for live lookup)" },
          season:           { type: "string",  description: "Season name like '2025/2026'" },
          force_refresh:    { type: "boolean", default: false, description: "Bypass DB cache, query CC live" }
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(meisterschaft_id: nil, tournament_id: nil, fed_id: nil, season: nil, force_refresh: false, server_context: nil)
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

        text(format_tournament_cc(tournament_cc))
      end

      def self.live_lookup(meisterschaft_id:, fed_id:, season:)
        return error("Missing meisterschaft_id for live lookup") if meisterschaft_id.blank?
        return error("Missing fed_id for live lookup") if fed_id.blank?
        client = cc_session.client_for
        params = { fedId: fed_id, meisterschaftId: meisterschaft_id }
        params[:season] = season if season.present?
        res, _doc = client.get("showMeisterschaft", params, { session_id: cc_session.cookie })
        return error("CC live-lookup failed: HTTP #{res&.code}") if res&.code != "200"
        text("CC live response for showMeisterschaft (meisterschaft_id=#{meisterschaft_id}, status #{res.code})")
      end

      def self.format_tournament_cc(tournament_cc)
        JSON.generate(
          id: tournament_cc.id,
          cc_id: tournament_cc.cc_id,
          name: tournament_cc.name,
          status: tournament_cc.status,
          season: tournament_cc.season,
          tournament_id: tournament_cc.tournament_id,
          context: tournament_cc.context
        )
      end
    end
  end
end
