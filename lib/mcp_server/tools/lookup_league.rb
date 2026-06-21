# frozen_string_literal: true

# cc_lookup_league — DB-first League lookup (D-02); live-fallback via showLeague.
#
# Plan 45-01: (a) NameError-Fix — live_lookup nimmt server_context als Param
# (vorher Z.49 referenziert, aber nicht im Signatur → Crash bei force_refresh:true).
# (b) DB-Pfad korrigiert: lieferte ohne league_id `LeagueCc...first` (eine BELIEBIGE
# Liga der Saison). Jetzt ueber League region-/saison-/disziplin-gefiltert; bei
# Mehrdeutigkeit Hinweis auf cc_list_leagues statt willkuerlicher Auswahl.

module McpServer
  module Tools
    class LookupLeague < BaseTool
      tool_name "cc_lookup_league"
      description "Wann nutzen? Wenn der User Details zu EINER konkreten Liga (Saison + Disziplin) braucht — Tabellenstand, Spielpaarungen, teilnehmende Mannschaften. Typisch für Liga-Auswertungen außerhalb des Turnier-Workflows. " \
                  "Was tippt der User typisch? 'Details Pool-Bezirksliga?', 'Saison 2025/2026 Liga 1234', 'lookup league'. " \
                  "Zum AUFLISTEN mehrerer Ligen (z.B. 'zeig die Pool-Ligen') stattdessen cc_list_leagues nutzen. " \
                  "Look up a ClubCloud league by internal league_id, by CC IDs (fed_id+branch_id+season), or by discipline within the user's region. " \
                  "Queries the local Carambus DB by default (League/LeagueCc mirror); pass force_refresh=true for live CC."
      input_schema(
        properties: {
          fed_id: {type: "integer", description: "ClubCloud federation ID. Optional — resolved via region lookup (CC_REGION/Setting 'context', default 'NBV'); ENV CC_FED_ID overrides."},
          branch_id: {type: "integer", description: "CC branch ID (e.g. 10 for Karambol). Nur für force_refresh/live-Pfad relevant."},
          season: {type: "string", description: "Season name like '2025/2026'. Default = aktuelle Saison."},
          league_id: {type: "integer", description: "CC league ID (leagueId / cc_id on LeagueCc) — eindeutigster Weg."},
          discipline: {type: "string", description: "Optionaler Branch-/Disziplin-Name ('Pool', 'Snooker', '8-Ball'). Engt den DB-Pfad ein. Branch-Name matched inkl. Sub-Disziplinen."},
          force_refresh: {type: "boolean", default: false, description: "Bypass DB cache, query CC live"}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(fed_id: nil, branch_id: nil, season: nil, league_id: nil, discipline: nil, force_refresh: false, server_context: nil)
        fed_id ||= default_fed_id(server_context)
        has_combination = fed_id.present? && branch_id.present? && season.present?
        if league_id.blank? && !has_combination && discipline.blank?
          return error("Missing required parameter: `league_id`, ODER `discipline` (z.B. 'Pool'), ODER die Kombination `fed_id`+`branch_id`+`season`. Zum Auflisten cc_list_leagues nutzen.")
        end

        return live_lookup(fed_id: fed_id, branch_id: branch_id, season: season, league_id: league_id, server_context: server_context) if force_refresh

        if league_id.present?
          league_cc = LeagueCc.find_by(cc_id: league_id)
          return error("League not found in Carambus DB (league_id=#{league_id}). Try force_refresh: true to query CC.") if league_cc.nil?
          return text(format_league_cc(league_cc, server_context))
        end

        # DB-Pfad ohne league_id: ueber League (NICHT LeagueCc.first), region-/saison-/
        # disziplin-gefiltert. Region strict via effective_cc_region (wie ListOpenTournaments).
        region_name = effective_cc_region(server_context)
        return scenario_config_missing_error if region_name.blank?
        region = Region.find_by(shortname: region_name)
        return error("Region '#{region_name}' nicht in Carambus gefunden — bitte LSW/SysAdmin informieren.") if region.nil?

        season_obj = effective_season(server_context, override: season)
        rel = League.where(organizer_type: "Region", organizer_id: region.id)
        rel = rel.where(season_id: season_obj.id) if season_obj

        if discipline.present?
          discipline_ids, = resolve_discipline_ids_inclusive(discipline)
          return error("Discipline oder Branch nicht gefunden: '#{discipline}'. Beispiele: 'Pool', 'Snooker', 'Karambol', '8-Ball'.") if discipline_ids.blank?
          rel = rel.where(discipline_id: discipline_ids)
        end

        matches = rel.limit(25).to_a
        if matches.empty?
          disc_part = discipline.present? ? ", Disziplin '#{discipline}'" : ""
          return error("Keine Liga gefunden (Region #{region.shortname}, Saison #{season_obj&.name}#{disc_part}). Nutze cc_list_leagues zum Auflisten oder force_refresh:true für Live-CC.")
        elsif matches.size > 1
          listing = matches.first(10).map { |l| "#{l.name} (league_id=#{l.id}, cc_id=#{l.cc_id})" }.join("; ")
          return text("Mehrere Ligen passen (#{matches.size}). Bitte über cc_list_leagues eingrenzen und dann mit `league_id` erneut anfragen. Treffer: #{listing}")
        end

        text(format_league(matches.first, server_context))
      end

      def self.live_lookup(fed_id:, branch_id:, season:, league_id:, server_context: nil)
        return error("Missing fed_id for live lookup") if fed_id.blank?
        client = cc_session.client_for(server_context)
        params = {fedId: fed_id}
        params[:branchId] = branch_id if branch_id.present?
        params[:season] = season if season.present?
        params[:leagueId] = league_id if league_id.present?
        res, _doc = client.get("showLeague", params, {session_id: cc_session.cookie})
        return error("CC live-lookup failed: HTTP #{res&.code}") if res&.code != "200"
        text("CC live response for showLeague (fed_id=#{fed_id}, status #{res.code})")
      end

      def self.season_id_for(season_name)
        Season.find_by(name: season_name)&.id
      end

      def self.format_league(league, server_context = nil)
        JSON.generate(
          league_id: league.id,
          cc_id: league.cc_id,
          name: league.name,
          shortname: league.shortname,
          discipline_id: league.discipline_id,
          discipline_name: league.discipline&.name,
          branch: league.branch&.name,
          season: league.season&.name,
          staffel_text: league.staffel_text,
          team_count: league.league_teams.size,
          source: source_label(server_context, :db_mirror) # Quelle (D-40-1): rechte-gegated, "" für read-only
        )
      end

      def self.format_league_cc(league_cc, server_context = nil)
        JSON.generate(
          id: league_cc.id,
          cc_id: league_cc.cc_id,
          name: league_cc.name,
          shortname: league_cc.shortname,
          status: league_cc.status,
          context: league_cc.context,
          source: source_label(server_context, :db_mirror) # Quelle (D-40-1): rechte-gegated, "" für read-only
        )
      end
    end
  end
end
