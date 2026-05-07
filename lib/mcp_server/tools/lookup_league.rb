# frozen_string_literal: true
# cc_lookup_league — DB-first League lookup by CC IDs (D-02); live-fallback via showLeague.

module McpServer
  module Tools
    class LookupLeague < BaseTool
      tool_name "cc_lookup_league"
      description "Look up a ClubCloud league by CC IDs (fed_id, branch_id, season) or internal league_id. " \
                  "Queries the local Carambus DB by default (LeagueCc mirror); pass force_refresh=true for live CC."
      input_schema(
        properties: {
          fed_id:        { type: "integer", description: "ClubCloud federation ID" },
          branch_id:     { type: "integer", description: "CC branch ID (e.g. 10 for Karambol)" },
          season:        { type: "string",  description: "Season name like '2025/2026'" },
          league_id:     { type: "integer", description: "CC league ID (leagueId / cc_id on LeagueCc)" },
          force_refresh: { type: "boolean", default: false, description: "Bypass DB cache, query CC live" }
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(fed_id: nil, branch_id: nil, season: nil, league_id: nil, force_refresh: false, server_context: nil)
        # Require at least league_id or (fed_id + branch_id + season)
        unless league_id.present? || (fed_id.present? && branch_id.present? && season.present?)
          return error("Missing required parameter: provide `league_id` or the combination of `fed_id`, `branch_id`, and `season`")
        end

        return live_lookup(fed_id: fed_id, branch_id: branch_id, season: season, league_id: league_id) if force_refresh

        league_cc = if league_id.present?
          LeagueCc.find_by(cc_id: league_id)
        else
          LeagueCc.joins(:season_cc).where(
            season_ccs: { season_id: season_id_for(season) }
          ).first
        end

        return error("League not found in Carambus DB. Try force_refresh: true to query CC.") if league_cc.nil?

        text(format_league_cc(league_cc))
      end

      def self.live_lookup(fed_id:, branch_id:, season:, league_id:)
        return error("Missing fed_id for live lookup") if fed_id.blank?
        client = cc_session.client_for
        params = { fedId: fed_id }
        params[:branchId] = branch_id if branch_id.present?
        params[:season] = season if season.present?
        params[:leagueId] = league_id if league_id.present?
        res, _doc = client.get("showLeague", params, { session_id: cc_session.cookie })
        return error("CC live-lookup failed: HTTP #{res&.code}") if res&.code != "200"
        text("CC live response for showLeague (fed_id=#{fed_id}, status #{res.code})")
      end

      def self.season_id_for(season_name)
        Season.find_by(name: season_name)&.id
      end

      def self.format_league_cc(league_cc)
        JSON.generate(
          id: league_cc.id,
          cc_id: league_cc.cc_id,
          name: league_cc.name,
          shortname: league_cc.shortname,
          status: league_cc.status,
          context: league_cc.context
        )
      end
    end
  end
end
