# frozen_string_literal: true

# cc_list_open_tournaments — DB-first Liste der Turniere einer Region.
#
# Plan 14-02.3 / F-1: Mode-Parameter für Date-Filter (upcoming/registration_open/
# active/recent) — Default `upcoming` (date >= today, Akkreditierung agnostisch).
# Behebt das Pre-14-02.3-Problem: Default-Filter blockte laufende Turniere
# (Meldeschluss vorbei, Spieltag noch in der Zukunft) wie die 21 NDM-Pool-Turniere.
#
# Plan 14-02.3 / F-2: Branch-Resolver. `discipline: "Pool"` matched alle
# Sub-Disciplines via Branch-STI (Pool/Snooker/Karambol/Kegel).
#
# Plan 14-02.3 / F-4: Output-ID-Naming konsistent. `tournament_id` (Carambus-id) +
# `cc_id` (TournamentCc.cc_id) zusätzlich. Verhindert Multi-Tool-Workflow-Bugs
# wo User „id" kopiert und das nächste Tool „nicht gefunden" wirft.
#
# Plan 14-02.3 / F-7: Season-Default-Filter via BaseTool.effective_season —
# Tools liefern by-default nur aktuelle-Saison-Records (kein Cross-Season-Noise).
#
# Plan 14-02.3 / B-4 + C-3: Strict region_id-Filter (DBU mit region_id=NULL
# automatisch raus); fed_id-Parameter aus input_schema entfernt (redundant).
#
# Sync-Realität: Local-Server pullt alle 2h via `carambus:retrieve_updates[1]`,
# d.h. DB ist auf Production max ~2h alt. Tool liefert `meta.last_sync_age_hours`
# als Datenfrische-Confirmer. Bei Nachmeldungen verschiebt der Verbandsadmin
# `accredation_end` direkt im CC — bis zum nächsten Pull (max 2h) kann die DB
# die Verschiebung nicht sehen → `force_refresh:true` empfehlen.

module McpServer
  module Tools
    class ListOpenTournaments < BaseTool
      tool_name "cc_list_open_tournaments"
      description "Wann nutzen? Wenn der Sportwart die aktuell offenen Turniere einer Region durchgehen will — z.B. zum Überblick was als nächstes ansteht oder zur Auswahl eines bestimmten Turniers nach Namen. " \
                  "Was tippt der User typisch? 'Welche Turniere sind offen?', 'Pool-Turniere zeigen', 'Liste offene Turniere'. " \
                  "Liste der Turniere einer Region in der aktuellen Saison. " \
                  "Mode-Parameter steuert den Date-Filter: 'upcoming' (default, date >= today; Akkreditierung egal — also auch laufende Turniere); " \
                  "'registration_open' (strict — accredation_end >= today; nur Turniere wo noch angemeldet werden kann); " \
                  "'active' (date in den nächsten 7 Tagen — Akkreditierung läuft / Turnier startet bald); " \
                  "'recent' (vorletzte Woche bis nächste 2 Wochen — für 'was war/ist gerade'-Fragen). " \
                  "DB-first; Tool liefert meta.last_sync_age_hours als Datenfrische-Confirmer (Production: max ~2h alt). " \
                  "Discipline-Filter akzeptiert Branch-Namen ('Pool' → alle Pool-Disciplines: 14.1, 8-Ball, 9-Ball, 10-Ball etc.) oder konkrete Discipline-Namen ('8-Ball'). " \
                  "Optionaler `name`-Filter macht eine case-insensitive Substring-Suche auf Tournament-Title. " \
                  "Output enthält tournament_id (Carambus-id) + cc_id (CC-cc_id) — beide nutzbar für Folge-Tools. " \
                  "Konversations-UX: Bei mehreren Treffern NICHT raten — Disambiguierung über Datum + Ort " \
                  "an den User stellen. Bei null Treffern dem User anbieten, mit weniger spezifischem Name-Fragment, " \
                  "anderem Mode oder ohne `discipline`-Filter erneut zu suchen. " \
                  "WICHTIG: Falls der Verbandsadmin gerade in CC den Meldeschluss verschoben hat (z.B. für Nachmeldungen), " \
                  "`force_refresh: true` setzen — sonst kann die DB bis zu 2h zurückliegen."
      input_schema(
        properties: {
          shortname: {type: "string", description: "Region-shortname (z.B. 'NBV'). Override (nur dokumentarisch) — strict-Modus aus 14-02.1-fix nutzt User#cc_region (server_context); Override wird mit Warning ignoriert wenn ungleich User-Region."},
          discipline: {type: "string", description: "Optionaler Filter: Branch-Name ('Pool', 'Karambol', 'Kegel', 'Snooker') oder Discipline-Name ('8-Ball', 'Dreiband') oder Discipline-ID (numerisch). Branch-Match liefert alle Sub-Disciplines."},
          mode: {type: "string", enum: %w[upcoming registration_open active recent], default: "upcoming", description: "Date-Filter-Modus. 'upcoming' (Default): date>=today (laufende + zukünftige Turniere). 'registration_open': accredation_end>=today (strict, alt-Default). 'active': date in den nächsten 7 Tagen. 'recent': vorletzte Woche bis nächste 2 Wochen."},
          season: {type: "string", description: "Season-Name (z.B. '2025/2026'). Default = aktuelle Saison."},
          name: {type: "string", description: "Optionaler Substring-Filter auf Tournament-Title (case-insensitive ILIKE)."},
          open_after: {type: "string", description: "ISO-Datum; default = today. Cutoff-Datum für Mode-Filter."},
          include_no_date: {type: "boolean", default: false, description: "Turniere ohne accredation_end mitnehmen (nur für mode='registration_open' relevant)."},
          force_refresh: {type: "boolean", default: false, description: "Bypass DB cache, triggert region_cc.sync_tournaments und re-runt den DB-Pfad."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(shortname: nil, discipline: nil, mode: "upcoming", season: nil, name: nil, open_after: nil, include_no_date: false, force_refresh: false, server_context: nil)
        # Plan 14-02.3 / B-3 + D-14-02-G: strict User-Context via effective_cc_region.
        # shortname-Parameter im Schema bleibt (Removal in 14-02.4) — Override wird mit
        # Warning ignoriert wenn ungleich User#cc_region.
        user_region_name = effective_cc_region(server_context)
        if shortname.present? && user_region_name.present? && shortname.to_s.upcase != user_region_name
          Rails.logger.warn "[cc_list_open_tournaments] shortname-Override '#{shortname}' ignoriert; nutze User#cc_region='#{user_region_name}'"
        end

        if user_region_name.blank?
          return scenario_config_missing_error
        end

        region = Region.find_by(shortname: user_region_name)
        if region.nil?
          return error("Region '#{user_region_name}' nicht in Carambus gefunden — bitte LSW/SysAdmin informieren.")
        end

        cutoff = parse_open_after(open_after)
        return error("Ungültiges open_after-Datum: #{open_after.inspect}. Erwartet: ISO-Format (z.B. '2026-05-15').") if cutoff.nil?

        # Plan 14-02.3 / F-2: Branch-Resolver via BaseTool DRY-Helper.
        discipline_ids = nil
        matched_branch = nil
        matched_discipline_name = nil
        if discipline.present?
          discipline_ids, matched_branch = resolve_discipline_or_branch(discipline)
          if discipline_ids.blank?
            return error(
              "Discipline oder Branch nicht gefunden: '#{discipline}'. " \
              "Beispiele: Branch-Namen 'Pool', 'Karambol', 'Kegel', 'Snooker' oder Discipline-Namen wie '8-Ball', 'Dreiband', 'Freie Partie klein'."
            )
          end
          if matched_branch.nil? && discipline_ids.size == 1
            matched_discipline_name = Discipline.find_by(id: discipline_ids.first)&.name
          end
        end

        # Plan 14-02.3 / F-7: Season-Default-Filter via BaseTool.effective_season.
        season_obj = effective_season(server_context, override: season)

        sync_completed_at = nil
        if force_refresh
          begin
            region.region_cc&.sync_tournaments({})
            sync_completed_at = Time.current
          rescue => e
            Rails.logger.warn "[cc_list_open_tournaments] sync_tournaments failed: #{e.class}: #{e.message}"
          end
        end

        # Plan 14-02.3 / B-4: strict region_id (DBU mit region_id=NULL automatisch raus).
        rel = Tournament.where(region_id: region.id).order(:date, :accredation_end)

        # Plan 14-02.3 / F-1: Mode-Parameter steuert Date-Filter.
        rel = apply_mode_filter(rel, mode.to_s, cutoff, include_no_date)

        # Plan 14-02.3 / F-7: Saison-Filter (by-default current_season).
        rel = rel.where(season_id: season_obj.id) if season_obj

        rel = rel.where(discipline_id: discipline_ids) if discipline_ids.present?

        if name.present?
          escaped = ActiveRecord::Base.sanitize_sql_like(name.to_s)
          rel = rel.where("title ILIKE ?", "%#{escaped}%")
        end

        last_sync = sync_completed_at || Tournament.where(region_id: region.id).maximum(:sync_date)
        last_sync_age_hours = last_sync ? ((Time.current - last_sync) / 3600.0).round(1) : nil

        # Plan 14-02.3 / F-4: tournament_id + cc_id + branch + discipline_name + season im Output.
        data = rel.includes(:discipline, :season, tournament_ccs: []).map { |t|
          tc = t.tournament_ccs.find { |x| x.context.to_s.downcase == user_region_name.to_s.downcase }
          {
            tournament_id: t.id,
            cc_id: tc&.cc_id,
            title: t.title,
            branch: t.discipline&.super_discipline&.name,
            discipline_id: t.discipline_id,
            discipline_name: t.discipline&.name,
            accredation_end: t.accredation_end&.iso8601,
            date: t.date&.iso8601,
            shortname: t.shortname,
            season: t.season&.name
          }
        }

        text(JSON.generate(
          data: data,
          meta: {
            region: region.shortname,
            count: data.length,
            last_sync_age_hours: last_sync_age_hours,
            mode: mode.to_s,
            filter_basis: build_filter_basis(mode.to_s, cutoff, include_no_date, name, matched_branch, matched_discipline_name),
            include_no_date: include_no_date,
            branch: matched_branch,
            discipline: matched_branch || matched_discipline_name,
            season: season_obj&.name,
            name: name
          }
        ))
      end

      # Plan 14-02.3 / F-1: Date-Filter-Modes. Default `upcoming` ist Akkreditierung-agnostisch
      # damit laufende Turniere (Meldeschluss vorbei, Spieltag noch da) nicht geblockt werden.
      def self.apply_mode_filter(rel, mode, cutoff, include_no_date)
        case mode
        when "upcoming"
          rel.where("date >= ?", cutoff)
        when "registration_open"
          if include_no_date
            rel.where("date >= ?", cutoff).where("accredation_end >= ? OR accredation_end IS NULL", cutoff)
          else
            rel.where("date >= ? AND accredation_end >= ?", cutoff, cutoff)
          end
        when "active"
          rel.where("date BETWEEN ? AND ?", cutoff, cutoff + 7.days)
        when "recent"
          rel.where("date BETWEEN ? AND ?", cutoff - 14.days, cutoff + 14.days)
        else
          rel.where("date >= ?", cutoff)
        end
      end

      def self.build_filter_basis(mode, cutoff, include_no_date, name, matched_branch, matched_discipline_name)
        parts = []
        case mode
        when "upcoming"
          parts << "date >= #{cutoff}"
        when "registration_open"
          parts << (include_no_date ? "date >= #{cutoff} AND (accredation_end >= #{cutoff} OR accredation_end IS NULL)" : "date >= #{cutoff} AND accredation_end >= #{cutoff}")
        when "active"
          parts << "date BETWEEN #{cutoff} AND #{cutoff + 7.days}"
        when "recent"
          parts << "date BETWEEN #{cutoff - 14.days} AND #{cutoff + 14.days}"
        end
        parts << "branch='#{matched_branch}'" if matched_branch
        parts << "discipline='#{matched_discipline_name}'" if matched_discipline_name
        parts << "title ILIKE '%#{name}%'" if name.present?
        parts.join(" AND ")
      end

      def self.parse_open_after(value)
        return Date.today if value.blank?
        Date.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
