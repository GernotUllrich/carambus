# frozen_string_literal: true

# cc_list_players_by_club_and_discipline — DB-first Liste der Spieler eines Vereins,
# die in der angegebenen Disziplin (für die aktuelle bzw. übergebene Saison) gerankt
# = spielberechtigt sind. Pattern: extends BaseTool, mirrors cc_lookup_region.

module McpServer
  module Tools
    class ListPlayersByClubAndDiscipline < BaseTool
      tool_name "cc_list_players_by_club_and_discipline"
      description "Wann nutzen? Wenn der Sportwart wissen will, welche Spieler eines Vereins für eine Disziplin spielberechtigt sind — z.B. vor der Anmeldung mehrerer Spieler aus dem eigenen Verein. " \
                  "Was tippt der User typisch? 'Welche BC-Wedel-Spieler dürfen Eurokegel spielen?', 'Spieler BVBW Cadre', 'list players BC Wedel Karambol'. " \
                  "Liste der spielberechtigten Spieler eines Vereins für eine Disziplin in einer Saison. " \
                  "Spielberechtigung wird via PlayerRanking-Join (player_id, discipline_id, region_id, season_id) " \
                  "ermittelt; PlayerClass-Lizenzklasse aktuell nicht berücksichtigt. DB-first; " \
                  "force_refresh:true triggert region_cc.sync_competitions und re-runt den DB-Pfad."
      input_schema(
        properties: {
          club: {type: "string", description: "Club-Shortname oder cc_id (numerisch). REQUIRED."},
          discipline: {type: "string", description: "Disziplin-Name oder numerische ID. REQUIRED."},
          season: {type: "string", description: "Saisonname (z.B. '2025/2026'). Default = Season.current_season."},
          shortname: {type: "string", description: "Region-shortname zur Validierung (Club gehört zur Region). Optional."},
          force_refresh: {type: "boolean", default: false, description: "Bypass DB cache, triggert region_cc.sync_competitions."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(club: nil, discipline: nil, season: nil, shortname: nil, force_refresh: false, server_context: nil)
        return error("Missing required parameter: `club`") if club.blank?
        return error("Missing required parameter: `discipline`") if discipline.blank?

        club_obj = resolve_club(club)
        return error("Club not found: #{club.inspect}") if club_obj.nil?

        discipline_obj = resolve_discipline(discipline)
        return error("Discipline not found: #{discipline.inspect}") if discipline_obj.nil?

        if shortname.present?
          region = Region.find_by(shortname: shortname.to_s.upcase)
          return error("Region not found: #{shortname.inspect}") if region.nil?
          if club_obj.region_id != region.id
            return error("Club '#{club_obj.shortname}' belongs to region_id=#{club_obj.region_id}, not '#{shortname}'.")
          end
        end

        season_obj = resolve_season(season)
        return error("Cannot determine season — pass `season:` param (Season.current_season returned nil).") if season_obj.nil?

        if force_refresh
          begin
            club_obj.region&.region_cc&.sync_competitions({})
          rescue => e
            Rails.logger.warn "[cc_list_players_by_club_and_discipline] sync_competitions failed: #{e.class}: #{e.message}"
          end
        end

        players = Player.joins(:season_participations, :player_rankings)
          .where(season_participations: {club_id: club_obj.id})
          .where(player_rankings: {
            discipline_id: discipline_obj.id,
            region_id: club_obj.region_id,
            season_id: season_obj.id
          })
          .distinct
          .order(:lastname, :firstname)

        text(JSON.generate(
          club: club_obj.shortname,
          discipline: discipline_obj.name,
          season: season_obj.name,
          count: players.count,
          players: players.map { |p|
            {
              id: p.id,
              fl_name: p.fl_name,
              lastname: p.lastname,
              firstname: p.firstname,
              cc_id: p.cc_id,
              ba_id: p.ba_id
            }
          }
        ))
      end

      def self.resolve_club(value)
        v = value.to_s
        if v.match?(/\A\d+\z/)
          Club.find_by(cc_id: v.to_i) || Club.find_by(id: v.to_i)
        else
          Club.find_by(shortname: v) || Club.find_by(name: v)
        end
      end

      def self.resolve_discipline(value)
        v = value.to_s
        return Discipline.find_by(id: v.to_i) if v.match?(/\A\d+\z/)
        Discipline.find_by(name: v)
      end

      def self.resolve_season(value)
        return Season.find_by(name: value.to_s) if value.present?
        Season.current_season
      end
    end
  end
end
