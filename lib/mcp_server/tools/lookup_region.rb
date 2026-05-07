# frozen_string_literal: true
# cc_lookup_region — DB-first Region lookup by shortname or fed_id (D-02).
# CANONICAL TEMPLATE — Task 1b mirrors this shape for 9 other read tools.
# D-18 acceptance-story foundation.

module McpServer
  module Tools
    class LookupRegion < BaseTool
      tool_name "cc_lookup_region"
      description "Look up a Carambus region by shortname (e.g. 'BCW') or ClubCloud federation ID. " \
                  "Returns region metadata from the local Carambus DB by default; pass force_refresh=true to query CC live."
      input_schema(
        properties: {
          shortname:     { type: "string",  description: "Region shortname like 'BCW'" },
          fed_id:        { type: "integer", description: "ClubCloud federation ID" },
          force_refresh: { type: "boolean", default: false, description: "Bypass DB cache, query CC live" }
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(shortname: nil, fed_id: nil, force_refresh: false, server_context: nil)
        err = validate_required_anyof!(shortname: shortname, fed_id: fed_id)
        return err if err

        return live_lookup(fed_id: fed_id) if force_refresh

        region = if shortname.present?
          Region.find_by(shortname: shortname)
        else
          region_cc = RegionCc.find_by(cc_id: fed_id)
          region_cc&.region
        end

        return error("Region not found in Carambus DB. Try force_refresh: true to query CC.") if region.nil?

        text(format_region(region))
      end

      # Validates that at least one of the anyof-required params is present.
      # Returns nil on success, error response on failure.
      def self.validate_required_anyof!(shortname:, fed_id:)
        return nil if shortname.present? || fed_id.present?
        error("Missing required parameter: provide at least one of `shortname` or `fed_id`")
      end

      def self.live_lookup(fed_id:)
        return error("Missing required parameter for live lookup: fed_id") if fed_id.blank?
        client = cc_session.client_for
        res, _doc = client.get("home", { fedId: fed_id }, { session_id: cc_session.cookie })
        return error("CC live-lookup failed: HTTP #{res&.code}") if res&.code != "200"
        text("CC live response for fed_id=#{fed_id} (status #{res.code})")
      end

      def self.format_region(region)
        JSON.generate(
          id: region.id,
          shortname: region.shortname,
          name: region.name,
          cc_id: region.region_cc&.cc_id
        )
      end
    end
  end
end
