# frozen_string_literal: true

# cc_list_open_tournaments — DB-first Liste der aktuell ausgeschriebenen Turniere
# einer Region. „Ausgeschrieben" ist reine Zeitlogik:
#   accredation_end >= today AND date >= today
# Der AASM-State spielt KEINE Rolle (User-Korrektur 2026-05-08, Plan 02-02 Round 3).
#
# Sync-Realität: Local-Server pullt alle 2h via `carambus:retrieve_updates[1]`,
# d.h. DB ist auf Production max ~2h alt. Tool liefert `meta.last_sync_age_hours`
# als Datenfrische-Confirmer. Edge-Case: bei Nachmeldungen verschiebt der
# Verbandsadmin `accredation_end` direkt im CC — bis zum nächsten Pull (max 2h)
# kann die DB die Verschiebung nicht sehen → `force_refresh:true` empfehlen.

module McpServer
  module Tools
    class ListOpenTournaments < BaseTool
      tool_name "cc_list_open_tournaments"
      description "Liste der aktuell ausgeschriebenen Turniere einer Region " \
                  "(accredation_end >= today AND date >= today). DB-first; Tool liefert " \
                  "meta.last_sync_age_hours als Datenfrische-Confirmer (Production: max ~2h alt). " \
                  "Optionaler `name`-Filter macht eine case-insensitive Substring-Suche auf Tournament-Title — " \
                  "passt zum Walking-Skeleton-Use-Case („gib mir den Status zu <Turnier-Name>\"). " \
                  "WICHTIG: Falls der Verbandsadmin gerade in CC den Meldeschluss " \
                  "verschoben hat (z.B. für Nachmeldungen), `force_refresh: true` setzen " \
                  "— sonst kann die DB bis zu 2h zurückliegen."
      input_schema(
        properties: {
          shortname: {type: "string", description: "Region-shortname (z.B. 'NBV'). Optional — Default via CC_REGION/Setting 'context'."},
          fed_id: {type: "integer", description: "ClubCloud federation ID. Alternative zu shortname."},
          discipline: {type: "string", description: "Optionaler Disziplin-Filter (Name oder numerische ID); weglassen = alle Disziplinen."},
          name: {type: "string", description: "Optionaler Substring-Filter auf Tournament-Title (case-insensitive ILIKE). Weglassen = alle Region/Disziplin/Zeit-Filter-Treffer."},
          open_after: {type: "string", description: "ISO-Datum; default = today. Filtert sowohl accredation_end als auch date."},
          include_no_date: {type: "boolean", default: false, description: "Turniere ohne accredation_end mitnehmen."},
          force_refresh: {type: "boolean", default: false, description: "Bypass DB cache, triggert region_cc.sync_tournaments und re-runt den DB-Pfad."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(shortname: nil, fed_id: nil, discipline: nil, name: nil, open_after: nil, include_no_date: false, force_refresh: false, server_context: nil)
        region = resolve_region(shortname: shortname, fed_id: fed_id)
        return error("Region not found. Provide shortname or fed_id, or set CC_REGION/Setting 'context'.") if region.nil?

        cutoff = parse_open_after(open_after)
        return error("Invalid open_after date: #{open_after.inspect}") if cutoff.nil?

        discipline_obj = nil
        if discipline.present?
          discipline_obj = resolve_discipline(discipline)
          return error("Discipline not found: #{discipline.inspect}") if discipline_obj.nil?
        end

        if force_refresh
          begin
            region.region_cc&.sync_tournaments({})
          rescue => e
            Rails.logger.warn "[cc_list_open_tournaments] sync_tournaments failed: #{e.class}: #{e.message}"
          end
        end

        rel = Tournament.where(region_id: region.id)
          .where("date >= ?", cutoff)
          .order(:accredation_end)

        rel = if include_no_date
          rel.where("accredation_end >= ? OR accredation_end IS NULL", cutoff)
        else
          rel.where("accredation_end >= ?", cutoff)
        end

        rel = rel.where(discipline_id: discipline_obj.id) if discipline_obj

        if name.present?
          escaped = ActiveRecord::Base.sanitize_sql_like(name.to_s)
          rel = rel.where("title ILIKE ?", "%#{escaped}%")
        end

        last_sync = Tournament.where(region_id: region.id).maximum(:sync_date)
        last_sync_age_hours = last_sync ? ((Time.current - last_sync) / 3600.0).round(1) : nil

        data = rel.map { |t|
          {
            id: t.id,
            title: t.title,
            accredation_end: t.accredation_end&.iso8601,
            date: t.date&.iso8601,
            discipline_id: t.discipline_id,
            shortname: t.shortname
          }
        }

        filter_basis_parts = ["accredation_end >= #{cutoff} AND date >= #{cutoff}"]
        filter_basis_parts << "title ILIKE '%#{name}%'" if name.present?

        text(JSON.generate(
          data: data,
          meta: {
            region: region.shortname,
            count: data.length,
            last_sync_age_hours: last_sync_age_hours,
            filter_basis: filter_basis_parts.join(" AND "),
            include_no_date: include_no_date,
            discipline: discipline_obj&.name,
            name: name
          }
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

      def self.parse_open_after(value)
        return Date.today if value.blank?
        Date.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
