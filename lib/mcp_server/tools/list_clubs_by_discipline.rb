# frozen_string_literal: true

# cc_list_clubs_by_discipline — DB-first Liste der Vereine einer Region, deren Spieler
# in einer bestimmten Disziplin gerankt sind (= eine PlayerRanking-Zeile haben).
# Pattern: extends BaseTool, mirrors cc_lookup_region (DB-first + force_refresh).

module McpServer
  module Tools
    class ListClubsByDiscipline < BaseTool
      tool_name "cc_list_clubs_by_discipline"
      description "Liste der Vereine in einer Region, deren Spieler in der angegebenen Disziplin " \
                  "gerankt sind (= spielberechtigt). DB-first; force_refresh:true triggert region_cc.sync_clubs " \
                  "und re-runt den DB-Pfad. Spielberechtigung wird via PlayerRanking-Join ermittelt; " \
                  "PlayerClass-Lizenzklasse aktuell nicht berücksichtigt."
      input_schema(
        properties: {
          shortname: {type: "string", description: "Region shortname (z.B. 'NBV'). Optional — Default via CC_REGION/Setting 'context'."},
          fed_id: {type: "integer", description: "ClubCloud federation ID. Alternative zu shortname."},
          discipline: {type: "string", description: "Disziplin-Name (z.B. 'Freie Partie klein') oder numerische ID (REQUIRED)."},
          force_refresh: {type: "boolean", default: false, description: "Bypass DB cache, zieht zuerst region_cc.sync_clubs, dann DB-Lookup."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(shortname: nil, fed_id: nil, discipline: nil, force_refresh: false, server_context: nil)
        return error("Missing required parameter: `discipline`") if discipline.blank?

        region = resolve_region(shortname: shortname, fed_id: fed_id)
        return error("Region not found. Provide shortname or fed_id, or set CC_REGION/Setting 'context'.") if region.nil?

        discipline_obj = resolve_discipline(discipline)
        return error("Discipline not found: #{discipline.inspect}") if discipline_obj.nil?

        if force_refresh
          begin
            region.region_cc&.sync_clubs({})
          rescue => e
            Rails.logger.warn "[cc_list_clubs_by_discipline] sync_clubs failed: #{e.class}: #{e.message}"
          end
        end

        clubs = Club.joins(players: :player_rankings)
          .where(region_id: region.id)
          .where(player_rankings: {discipline_id: discipline_obj.id, region_id: region.id})
          .distinct
          .order(:shortname)

        text(JSON.generate(
          region: region.shortname,
          discipline: discipline_obj.name,
          count: clubs.count,
          clubs: clubs.map { |c| {id: c.id, shortname: c.shortname, name: c.name, cc_id: c.cc_id} }
        ))
      end

      def self.resolve_region(shortname:, fed_id:)
        if shortname.present?
          Region.find_by(shortname: shortname.to_s.upcase)
        elsif fed_id.present?
          RegionCc.find_by(cc_id: fed_id)&.region
        else
          fallback_id = default_fed_id
          fallback_id ? RegionCc.find_by(cc_id: fallback_id)&.region : nil
        end
      end

      def self.resolve_discipline(value)
        v = value.to_s
        return Discipline.find_by(id: v.to_i) if v.match?(/\A\d+\z/)
        Discipline.find_by(name: v)
      end
    end
  end
end
