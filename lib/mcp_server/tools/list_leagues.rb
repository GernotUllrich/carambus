# frozen_string_literal: true

# cc_list_leagues — DB-first Liste der Ligen einer Region (Pool-first).
#
# Plan 45-01: Liga-Discovery-Einstieg fürs Party-/Liga-Lese-Fundament (v1.2). Der
# Pool-Sportwart denkt in "zeig die Pool-Ligen", nicht in cc_id/branch/season — dieses
# Tool ist der Einstieg, von dem aus cc_lookup_league (Detail einer Liga) angesteuert wird.
#
# Region-Scope via organizer (RegionTaggable: League#find_associated_region_id =
# organizer_type=="Region" ? organizer_id). Disziplin-Filter akzeptiert Branch-Namen
# ('Pool' → alle Pool-Disziplinen INKL. Branch-Root, da Ligen direkt am Branch-Root
# hängen — anders als Turniere; resolve_discipline_ids_inclusive). Muster: ListOpenTournaments.

module McpServer
  module Tools
    class ListLeagues < BaseTool
      tool_name "cc_list_leagues"
      description "Wann nutzen? Wenn der Sportwart die Ligen seiner Region durchgehen will — z.B. 'welche Pool-Ligen gibt es?', Überblick über Mannschaftswettbewerbe, oder zur Auswahl einer Liga für Detail-Lookup. " \
                  "Was tippt der User typisch? 'Zeig die Pool-Ligen', 'welche Ligen laufen?', 'Liste Snooker-Ligen'. " \
                  "Liste der Ligen einer Region in der aktuellen Saison (DB-first). " \
                  "Discipline-Filter akzeptiert Branch-Namen ('Pool' → alle Pool-Ligen inkl. Sub-Disziplinen; 'Snooker', 'Karambol', 'Kegel') oder konkrete Discipline-Namen ('8-Ball'). " \
                  "Optionaler `name`-Filter macht eine case-insensitive Substring-Suche auf Liga-Name/Kurzname. " \
                  "Output je Zeile: league_id (Carambus-id) + cc_id — beide nutzbar für cc_lookup_league. " \
                  "Konversations-UX: Bei vielen Treffern dem User Eingrenzung (Disziplin/Name) anbieten; bei null Treffern weniger spezifisch erneut suchen."
      input_schema(
        properties: {
          discipline: {type: "string", description: "Optionaler Filter: Branch-Name ('Pool', 'Snooker', 'Karambol', 'Kegel') oder Discipline-Name ('8-Ball', 'Dreiband') oder Discipline-ID (numerisch). Branch-Match liefert alle Sub-Disziplinen inkl. Branch-Root."},
          season: {type: "string", description: "Season-Name (z.B. '2025/2026'). Default = aktuelle Saison."},
          name: {type: "string", description: "Optionaler Substring-Filter auf Liga-Name/Kurzname (case-insensitive ILIKE)."},
          force_refresh: {type: "boolean", default: false, description: "Bypass DB cache, triggert region_cc.sync_leagues (defensiv) und re-runt den DB-Pfad."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(discipline: nil, season: nil, name: nil, force_refresh: false, server_context: nil)
        region_name = effective_cc_region(server_context)
        return scenario_config_missing_error if region_name.blank?
        region = Region.find_by(shortname: region_name)
        return error("Region '#{region_name}' nicht in Carambus gefunden — bitte LSW/SysAdmin informieren.") if region.nil?

        discipline_ids = nil
        matched_branch = nil
        matched_discipline_name = nil
        if discipline.present?
          discipline_ids, matched_branch = resolve_discipline_ids_inclusive(discipline)
          if discipline_ids.blank?
            return error(
              "Discipline oder Branch nicht gefunden: '#{discipline}'. " \
              "Beispiele: Branch-Namen 'Pool', 'Snooker', 'Karambol', 'Kegel' oder Discipline-Namen wie '8-Ball', '9-Ball', 'Dreiband'."
            )
          end
          if matched_branch.nil? && discipline_ids.size == 1
            matched_discipline_name = Discipline.find_by(id: discipline_ids.first)&.name
          end
        end

        season_obj = effective_season(server_context, override: season)

        if force_refresh && season_obj
          begin
            region.region_cc&.sync_leagues(context: region.shortname.downcase, season_name: season_obj.name)
          rescue => e
            Rails.logger.warn "[cc_list_leagues] sync_leagues failed: #{e.class}: #{e.message}"
          end
        end

        # Region-Scope: League ist über organizer (Region) der Region zugeordnet
        # (RegionTaggable#find_associated_region_id). Am Datenbestand verifiziert
        # (Plan 45-01): NBV-Pool-Ligen 2025/26 → organizer_type='Region', organizer_id=NBV.
        rel = League.where(organizer_type: "Region", organizer_id: region.id).order(:name)
        rel = rel.where(season_id: season_obj.id) if season_obj
        rel = rel.where(discipline_id: discipline_ids) if discipline_ids.present?

        if name.present?
          escaped = ActiveRecord::Base.sanitize_sql_like(name.to_s)
          rel = rel.where("leagues.name ILIKE ? OR leagues.shortname ILIKE ?", "%#{escaped}%", "%#{escaped}%")
        end

        # Sportwart-Disziplin-Wirkbereich EINMAL aufloesen (kein N+1), hierarchie-bewusst
        # via root_chain — analog ListOpenTournaments. Liste wird NICHT gefiltert, nur markiert.
        scope_user = User.find_by(id: server_context&.dig(:user_id))
        scoped_disc_ids = if scope_user&.respond_to?(:sportwart?) && scope_user.sportwart?
          Array(scope_user.sportwart_discipline_ids)
        else
          []
        end

        data = rel.includes(:discipline, :season, :league_teams).map { |l|
          row = {
            league_id: l.id,
            cc_id: l.cc_id,
            name: l.name,
            shortname: l.shortname,
            branch: l.branch&.name,
            discipline_id: l.discipline_id,
            discipline_name: l.discipline&.name,
            staffel_text: l.staffel_text,
            season: l.season&.name,
            team_count: l.league_teams.size
          }
          unless scoped_disc_ids.empty?
            in_scope = (Array(l.discipline&.root_chain).map(&:id) & scoped_disc_ids).any?
            row[:in_scope] = in_scope
            row[:scope_hint] = "außerhalb deines Wirkbereichs" unless in_scope
          end
          row
        }

        text(JSON.generate(
          data: data,
          meta: {
            region: region.shortname,
            count: data.length,
            branch: matched_branch,
            discipline: matched_branch || matched_discipline_name,
            season: season_obj&.name,
            name: name,
            # Phase 40 (D-40-1): interne Quelle (DB-Abbild) rechte-gegated; "" für read-only User.
            source: source_label(server_context, :db_mirror),
            your_scope_disciplines: scoped_disc_ids.empty? ? nil : Discipline.where(id: scoped_disc_ids).pluck(:name)
          }
        ))
      end
    end
  end
end
