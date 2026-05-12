# frozen_string_literal: true

# cc_lookup_club — DB-first lookup mit cc_id (direkt) ODER Name/Shortname/Synonym-Search.
#
# Plan 10-05 Task 3 (Befund #9 D-10-03-4): Sportwart denkt in Vereinsnamen
# („BC Wedel" → cc_id 1010), nicht in cc_ids. Tool unterstützt jetzt 3 Input-Modi:
#   - cc_id: direkter Lookup (bisheriges Verhalten; jetzt mit Region-Filter)
#   - name: DB-First-Search auf name/shortname/synonyms via ILIKE
#   - shortname: gezielter shortname-Match (z.B. "BCW" → BC Wedel)
# Mit Disambiguation-Output-Pattern aus Phase 8 (candidates-Array): 0/1/≥2-Treffer.

module McpServer
  module Tools
    class LookupClub < BaseTool
      tool_name "cc_lookup_club"
      description "Verein-Lookup (DB-first) via cc_id ODER Name/Shortname/Synonym-Suche. " \
                  "Wann nutzen? — Wenn Sportwart fragt 'gibt es Verein XYZ?' oder du brauchst eine " \
                  "club_cc_id für ein Register-Tool. Was tippt der User typisch? — 'wo gibt's BC Wedel?', " \
                  "'lookup Verein Billiard-Club Wedel', 'finde club shortname BCW'. " \
                  "Suche per default in der Default-Region (CC_REGION/Setting 'context'); optional " \
                  "`region_shortname` für Cross-Region-Lookup. Output mit Disambiguation: " \
                  "0 Treffer → Error mit attempted-Details; 1 Treffer → top-level cc_id + candidates-Array; " \
                  "≥2 Treffer → cc_id:null + candidates + warning (Claude fragt User rück). " \
                  "Synonym-Match-Hervorhebung: trifft die Suche auf Club.synonyms (statt name/shortname), " \
                  "zeigt 'synonyms_matched' welche Alt-Schreibweise getroffen wurde — Sportwart-Vertrauensaufbau."
      input_schema(
        properties: {
          cc_id: {type: "integer", description: "ClubCloud club cc_id (direkter Lookup; bypasst Name-Search)."},
          name: {type: "string", description: "Substring-Suche auf Club.name ODER Club.synonyms (case-insensitive ILIKE). Vereins-Vollnamen oder Teil davon ('BC Wedel', 'Billiard Club')."},
          shortname: {type: "string", description: "Substring-Suche auf Club.shortname (case-insensitive ILIKE; z.B. 'BCW')."},
          region_shortname: {type: "string", description: "Optionaler Region-Filter-Override (z.B. 'BVBW'). Default: CC_REGION/Setting 'context'/'NBV'."},
          fed_id: {type: "integer", description: "ClubCloud federation ID (deprecated — Region-Filter via region_shortname bevorzugt). Optional Backwards-Compat."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(cc_id: nil, name: nil, shortname: nil, region_shortname: nil, fed_id: nil, server_context: nil)
        # OneOf-Validation (analog Phase-6 Pattern): mind. ein Input-Param erforderlich
        unless cc_id.present? || name.present? || shortname.present?
          return error("Missing required parameter: provide `cc_id`, `name`, or `shortname`.")
        end

        region = resolve_region(region_shortname)

        scope = Club.all
        scope = scope.where(region_id: region.id) if region

        matches = if cc_id.present?
          scope.where(cc_id: cc_id)
        elsif shortname.present? && name.blank?
          search = "%#{ActiveRecord::Base.sanitize_sql_like(shortname.to_s)}%"
          scope.where("shortname ILIKE ?", search)
        else
          # name-Search (kombiniert mit optionalem shortname)
          search = "%#{ActiveRecord::Base.sanitize_sql_like(name.to_s)}%"
          rel = scope.where("name ILIKE ? OR synonyms ILIKE ? OR shortname ILIKE ?", search, search, search)
          if shortname.present?
            sn_search = "%#{ActiveRecord::Base.sanitize_sql_like(shortname.to_s)}%"
            rel = rel.where("shortname ILIKE ?", sn_search)
          end
          rel
        end

        matches = matches.order(:name).limit(20)
        candidates = matches.map { |c| format_candidate(c, name: name) }

        if candidates.empty?
          return error(format_no_match(cc_id: cc_id, name: name, shortname: shortname, region: region))
        end

        body = {
          cc_id: (candidates.length == 1) ? candidates.first[:cc_id] : nil,
          candidates: candidates,
          meta: {
            count: candidates.length,
            region: region&.shortname,
            search: {cc_id: cc_id, name: name, shortname: shortname}.compact
          }
        }
        body[:warning] = "#{candidates.length} Treffer gefunden — bitte Sportwart-Rückfrage: welcher Verein?" if candidates.length > 1
        text(JSON.generate(body))
      end

      # Region-Resolver (analog cc_lookup_tournament Plan 10-05 Task 2).
      def self.resolve_region(override = nil)
        shortname = if override.present?
          override.to_s.upcase
        elsif ENV["CC_REGION"].present?
          ENV["CC_REGION"].upcase
        else
          context = (defined?(Setting) ? Setting.key_get_value("context") : nil).presence
          (context || "NBV").upcase
        end
        Region.find_by(shortname: shortname)
      rescue => e
        Rails.logger.warn "[cc_lookup_club.resolve_region] #{e.class}: #{e.message}"
        nil
      end

      # Formatiert einen Treffer mit synonyms_matched-Hervorhebung falls der Match
      # auf Club.synonyms (newline-getrennte Alt-Schreibweisen) erfolgte.
      def self.format_candidate(club, name: nil)
        candidate = {
          cc_id: club.cc_id,
          name: club.name,
          shortname: club.shortname,
          region_shortname: club.region&.shortname
        }

        # Synonyms-Match-Hervorhebung: matched-Zeile aus synonyms-Text extrahieren
        if name.present? && club.synonyms.present?
          needle = name.to_s.downcase
          matched_lines = club.synonyms.to_s.split("\n").select { |line|
            line.downcase.include?(needle)
          }
          candidate[:synonyms_matched] = matched_lines unless matched_lines.empty?
        end

        candidate
      end

      def self.format_no_match(cc_id:, name:, shortname:, region:)
        attempted = {cc_id: cc_id, name: name, shortname: shortname}.compact
        region_label = region&.shortname || "default-region"
        "Kein Verein in Region '#{region_label}' passt zu den Suchparametern: #{attempted.inspect}. " \
          "Versuche: (a) shortname-Variante (z.B. 'BCW' statt 'BC Wedel'), (b) Teilstring (z.B. 'Wedel'), " \
          "(c) region_shortname-Override falls Cross-Region-Lookup gewünscht (z.B. region_shortname:'BVBW'), " \
          "(d) cc_id falls bekannt."
      end
    end
  end
end
