# frozen_string_literal: true

# BaseTool — Common Helpers für alle MCP-Tool-Subklassen.
# MCP::Tool#input_schema ist deskriptiv, NICHT runtime-validation (Pitfall 6) —
# daher manuell validieren und strukturierten Error zurückgeben.
#
# SDK-API findings (verified by Task 3 SDK-API smoke probe — see Plan 01 SUMMARY):
# - `tool_name`, `description`, `input_schema`, `annotations` are class-level DSL macros
# - `MCP::Tool::Response.new(content, error: bool)` exposes `#error?` (predicate!) and `#content`
#   ACHTUNG: SDK 0.15 hat `error?` NICHT `error` — Plans 04+05 müssen `response.error?` nutzen

module McpServer
  module Tools
    class BaseTool < MCP::Tool
      # Construct an error response in the SDK-canonical shape.
      def self.error(message)
        MCP::Tool::Response.new([{type: "text", text: message}], error: true)
      end

      # Construct a text response.
      def self.text(message)
        MCP::Tool::Response.new([{type: "text", text: message}])
      end

      # Manually validate that all required keys in the schema are present.
      # Returns nil on success, error response on failure.
      def self.validate_required!(args, required_keys)
        missing = required_keys.reject { |k| args[k.to_sym] || args[k.to_s] }
        return nil if missing.empty?
        error("Missing required parameter(s): #{missing.join(", ")}")
      end

      # Returns true if CARAMBUS_MCP_MOCK is set; tools should branch their CC-call paths.
      def self.mock_mode?
        ENV["CARAMBUS_MCP_MOCK"] == "1"
      end

      # Lazy CC-client accessor — Tools delegate to McpServer::CcSession (Plan 01 Task 2).
      def self.cc_session
        McpServer::CcSession
      end

      # Plan 10-05 Task 4 (Befund #8 D-10-03-5): Pre-Read-Verify-Status-Helper für Write-Tools.
      # Sportwart kann manuell eingegebene cc_id (meldeliste_cc_id, player_cc_id) nicht
      # selbständig verifizieren. Vorhandenes Pattern `read_back_match` zeigt nach-Schreib-Status,
      # NICHT vor-Schreib-Resolution. Helper gibt strukturierten Status zurück (verified/source/warning).
      #
      # source-Werte:
      #   "DB-resolver"      — cc_id aus DB-Beziehung resolved (z.B. TournamentCc.registration_list_cc)
      #   "live-CC-fallback" — cc_id via Pre-Read-CC-Call verifiziert (read-only, vor Mutation)
      #   "override-param"   — User-Override; KEINE Pre-Read-Verifikation (Vertrauens-Lücke)
      #
      # Verwendung in Write-Tools:
      #   result.merge(format_pre_read_status(verified: true, source: "DB-resolver"))
      #   result.merge(format_pre_read_status(verified: false, source: "override-param",
      #                                       warning: "meldeliste_cc_id=#{x} als Override ohne Pre-Read-Verify"))
      def self.format_pre_read_status(verified:, source:, warning: nil)
        status = {
          pre_read_verified: verified,
          pre_read_source: source
        }
        status[:pre_read_warning] = warning if warning
        status
      end

      # Plan 10-05.1 Task 1 (D-10-04-B/G Pre-Validation-First-Pattern):
      # Konvention: Tools definieren private `_validate_*`-Methoden, jede returnt:
      #   {name: "constraint_name", ok: true/false, reason: "specific msg if !ok"}
      # `run_validations` sammelt alle Results und liefert:
      #   {all_passed: bool, results: [...], failed_constraints: ["name1", ...]}
      #
      # Validations können entweder Hashes (sofort evaluiert) ODER Lambdas
      # (lazy-evaluated für conditional Pre-Read-Calls) sein.
      def self.run_validations(validations)
        results = validations.map { |v| v.respond_to?(:call) ? v.call : v }
        failed = results.reject { |r| r[:ok] }
        {
          all_passed: failed.empty?,
          results: results,
          failed_constraints: failed.map { |r| r[:name] }
        }
      end

      # Plan 10-06 Task 3 (D-10-04-J Convenience-Wrapper):
      # Auto-Resolve club_cc_id aus club_name via cc_lookup_club (DRY für 3 Write-Tools).
      # Returns [resolved_cc_id, error_message] tuple — bei error: cc_id=nil + Diagnose-String.
      def self.resolve_club_cc_id_from_name(club_cc_id:, club_name:, server_context: nil)
        return [club_cc_id, nil] if club_cc_id.present?
        return [nil, nil] if club_name.blank?  # Both nil → caller-Validation handelt das

        result = McpServer::Tools::LookupClub.call(name: club_name, server_context: server_context)
        if result.error?
          return [nil, "Club-Lookup für '#{club_name}' fehlgeschlagen: #{result.content.first[:text]}"]
        end

        body = JSON.parse(result.content.first[:text])
        if body["cc_id"].nil?
          candidates_str = body["candidates"].map { |c| "#{c["name"]} (cc_id=#{c["cc_id"]})" }.join(", ")
          return [nil, "Mehrere Vereine passen zu '#{club_name}': #{candidates_str}. Bitte präziser angeben oder club_cc_id direkt."]
        end
        [body["cc_id"], nil]
      rescue => e
        Rails.logger.warn "[BaseTool.resolve_club_cc_id_from_name] #{e.class}: #{e.message}"
        [nil, "Club-Auto-Resolve-Exception: #{e.class.name}"]
      end

      # Plan 10-06 Task 3 (D-10-04-J Convenience-Wrapper):
      # Auto-Resolve player_cc_id aus player_name via cc_search_player (DRY für 3 Write-Tools).
      def self.resolve_player_cc_id_from_name(player_cc_id:, player_name:, server_context: nil)
        return [player_cc_id, nil] if player_cc_id.present?
        return [nil, nil] if player_name.blank?

        result = McpServer::Tools::SearchPlayer.call(query: player_name, server_context: server_context)
        if result.error?
          return [nil, "Player-Lookup für '#{player_name}' fehlgeschlagen: #{result.content.first[:text]}"]
        end

        body = JSON.parse(result.content.first[:text])
        if body["cc_id"].nil?
          candidates_str = body["candidates"].map { |c| "#{c["name"]} (cc_id=#{c["cc_id"]})" }.join(", ")
          return [nil, "Mehrere Spieler passen zu '#{player_name}': #{candidates_str}. Bitte präziser angeben oder player_cc_id direkt."]
        end
        [body["cc_id"], nil]
      rescue => e
        Rails.logger.warn "[BaseTool.resolve_player_cc_id_from_name] #{e.class}: #{e.message}"
        [nil, "Player-Auto-Resolve-Exception: #{e.class.name}"]
      end

      # Liefert die ClubCloud federation_id als Default-Fallback für Tools.
      # Priorität:
      #   1. ENV["CC_FED_ID"] (expliziter Override — höchste Prio)
      #   2. Region-Lookup via CC_REGION-ENV oder Setting context (kanonisch)
      #   3. nil — bestehender "Missing required parameter: fed_id"-Fehler bleibt erhalten
      #
      # Defensiv: rescued StandardError, damit Mock-Smoke-Tests ohne DB nicht crashen.
      # Plan 14-02.1-fix / D-14-02-G: Multi-User-Production-Pflicht — kein ENV["CC_FED_ID"]-
      # Shortcut. Ableitung strict via effective_cc_region (jetzt strict) → Region → RegionCc.cc_id.
      def self.default_fed_id(server_context = nil)
        cc_region = effective_cc_region(server_context)
        return nil if cc_region.blank?
        region = Region.find_by(shortname: cc_region)
        region&.region_cc&.cc_id
      rescue => e
        Rails.logger.warn "[BaseTool.default_fed_id] Region lookup failed: #{e.class}"
        nil
      end

      # Plan 14-G.2 / D-14-G3 + D-13-04-B PARTIAL (Hot-Fix 14-G.6.1):
      # Source-of-Truth wechselt von User#cc_region (gedroppt per D-14-G6) zu
      # Carambus.config.context (Scenario-Config — kanonischer Region-Shortname-Key
      # seit Jahren etabliert; z.B. scenario_generator.rb, cleanup.rake, carambus.rake).
      # 14-G.2-Pre-Decision-Error: hatte fälschlich einen NEUEN Key `region_id` eingeführt;
      # Hot-Fix in 14-G.6.1 reverted auf bestehenden `context`-Key.
      # server_context[:cc_region] bleibt als Backwards-Compat-Fallback erhalten
      # (Test-Setups, die explizit Context setzen ohne carambus.yml zu mutieren).
      # UPPERCASE-Convention (Region#shortname in Carambus ist UPPERCASE).
      def self.effective_cc_region(server_context = nil)
        config_region = Carambus.config.context.to_s if Carambus.config.respond_to?(:context)
        return config_region.upcase if config_region.present?
        ctx_region = server_context&.dig(:cc_region)
        return ctx_region.to_s.upcase if ctx_region.is_a?(String) && ctx_region.present?
        nil
      end

      # Plan 14-02.2 / Befund E-1 (Title-Präfix-Bug): Token-Search-Helper für tolerante
      # Name-Suche. "Dr. Gernot Ullrich" → ["Dr.", "Gernot", "Ullrich"]; jeder Token
      # AND-verknüpft als ILIKE-Pattern. Behebt das Problem, dass naive ILIKE-Substring
      # "Gernot Ullrich" (User-Vokabular) nicht gegen DB-Wert "Dr. Gernot Ullrich" matched.
      # Min-Token-Länge 2 Zeichen (kürzere Tokens raus — verhindert Wildcard-Explosion).
      def self.tokenize_search_query(query)
        return [] if query.blank?
        query.to_s.strip.split(/\s+/).map(&:strip).reject { |t| t.size < 2 }
      end

      # Plan 14-02.2 / Befund E-1: DRY-Filter-Helper für Token-Search.
      # `columns` z.B. ["firstname", "lastname", "fl_name"]; jeder Token muss in
      # mindestens einer column als Substring matchen (AND zwischen Tokens, OR
      # zwischen Columns innerhalb eines Tokens).
      # ActiveRecord::Base.sanitize_sql_like wird intern angewendet.
      def self.apply_token_search_filter(scope, tokens, columns)
        return scope if tokens.empty?
        tokens.reduce(scope) do |current_scope, token|
          escaped = ActiveRecord::Base.sanitize_sql_like(token)
          like_pattern = "%#{escaped}%"
          token_clause = columns.map { |col| "#{col} ILIKE ?" }.join(" OR ")
          current_scope.where(token_clause, *Array.new(columns.size, like_pattern))
        end
      end

      # Plan 14-02.2: Detect Title-Präfixe im Query (Dr./Prof./Dr.-Ing./Dipl.-Ing./Mag./
      # Mag.iur./M.Sc./B.Sc./Med./vet./jur./phil./MA/MBA usw.) — gibt das erste matchende
      # Präfix als informativen Hinweis zurück (nicht-filternd). Nutzbar für Output-
      # Annotation: "title_prefix_detected: 'Dr.'" damit Sportwart weiß, dass die Suche
      # Title-tolerant gelaufen ist.
      # NOTE: Title-Patterns mit Punkt nutzen Look-Ahead statt \b weil \b mit "." nicht endet.
      TITLE_PREFIX_PATTERNS = [
        /(?:\A|\s)(Dr\.-Ing\.?)(?=\s|\z)/i,
        /(?:\A|\s)(Dipl\.-Ing\.?)(?=\s|\z)/i,
        /(?:\A|\s)(Prof\.)(?=\s|\z)/i,
        /(?:\A|\s)(Dr\.)(?=\s|\z)/i,
        /(?:\A|\s)(Mag\.)(?=\s|\z)/i,
        /(?:\A|\s)(M\.Sc\.?)(?=\s|\z)/i,
        /(?:\A|\s)(B\.Sc\.?)(?=\s|\z)/i,
        /(?:\A|\s)(Prof)(?=\s|\z)/i,
        /(?:\A|\s)(Dr)(?=\s|\z)/i
      ].freeze

      def self.detect_title_prefix(query)
        return nil if query.blank?
        TITLE_PREFIX_PATTERNS.each do |pattern|
          m = query.to_s.match(pattern)
          return m[1] if m
        end
        nil
      end

      # Plan 14-02.1 / D-14-02-D: TournamentCc#cc_id ist nur intra-region-eindeutig
      # (User-Klarstellung 2026-05-14). Auf carambus.de sind alle Regionen gemirrort,
      # d.h. dieselbe cc_id kann mehreren TournamentCcs entsprechen (z.B. 890 = NBV-NDM-
      # Endrunde Eurokegel UND BLMR-NRW-Meisterschaft mU15 10-Ball). Lookup-Pfad daher
      # immer (cc_id, context)-Tuple, wobei context = region.shortname.downcase (z.B. "nbv").
      #
      # Returnt nil bei:
      #   - fehlendem cc_id
      #   - fehlendem server_context (defensive; ohne Context-Region keine Disambiguation)
      #   - kein Match in der Server-Context-Region (cross-region-Mismatch ist NICHT silent
      #     fallback — Tool muss explizit Diagnostic-Error werfen)
      def self.resolve_tournament_cc(cc_id:, server_context: nil)
        return nil if cc_id.blank?
        context = effective_cc_region(server_context).to_s.downcase
        return nil if context.blank?
        TournamentCc.find_by(cc_id: cc_id.to_i, context: context)
      end

      # Plan 14-02.3 / F-7: Season-Default-Helper. Tournament-Lookup/List-Tools filtern
      # by-default auf die aktuelle Saison; optional via override-Parameter umschaltbar.
      # Saison-Modell: Season.current_season existiert bereits in app/models/season.rb
      # (delegiert auf "year/year+1"-Naming-Convention mit 6-Monats-Cutoff).
      #
      # override → exakter Season-Name (z.B. "2025/2026"); nicht gefunden → current_season.
      # Defensive: rescued StandardError damit Mock-/Test-Pfade ohne Season-Fixtures nicht crashen.
      def self.effective_season(server_context = nil, override: nil)
        if override.present?
          found = Season.find_by(name: override.to_s)
          return found if found
          Rails.logger.warn "[BaseTool.effective_season] Season-Override '#{override}' nicht gefunden; nutze current_season"
        end
        Season.current_season
      rescue => e
        Rails.logger.warn "[BaseTool.effective_season] #{e.class}: #{e.message}"
        nil
      end

      # Plan 14-02.3 / F-7: Season-Derivation aus Datum. Notwendig weil TournamentCc.season
      # im DB-Mirror häufig null ist (Sync-Bug, v0.4-Backlog-Item).
      # Carambus-Saison-Convention: 1. Juli = Cutoff. Date in "2025/2026" wenn
      # 2025-07-01 <= date <= 2026-06-30 (siehe Season#season_from_date für Vergleich;
      # identisches Verhalten via Juli-Cutoff statt 6-Monats-Subtraktion).
      def self.derive_season_from_date(date)
        return nil if date.nil?
        d = date.respond_to?(:to_date) ? date.to_date : Date.parse(date.to_s)
        year = (d.month >= 7) ? d.year : d.year - 1
        Season.find_by(name: "#{year}/#{year + 1}")
      rescue => e
        Rails.logger.warn "[BaseTool.derive_season_from_date] #{e.class}: #{e.message}"
        nil
      end

      # Plan 14-02.3 / F-2: Branch-Resolver für Discipline-Filter in Tournament-Read-Tools.
      # Carambus-Datenmodell: `Branch` ist STI-Subklasse von `Discipline` (type='Branch';
      # 4 Branches: Pool=23, Snooker=24, Karambol=50, Kegel=55). Reguläre Disciplines
      # zeigen via super_discipline_id auf ihre Branch.
      #
      # Resolver-Reihenfolge:
      #   1. Branch-Match (case-insensitive ILIKE) → alle Sub-Disciplines liefern
      #   2. Discipline-Match (case-insensitive ILIKE) → einzelne Discipline
      #   3. Numerische Discipline-ID-Fallback
      #
      # Returns [discipline_ids, branch_name] tuple:
      #   - [nil, nil] bei blank/nicht gefunden
      #   - [[id1, id2, ...], "Pool"] bei Branch-Match
      #   - [[id], nil] bei Discipline-Match
      def self.resolve_discipline_or_branch(filter_string)
        return [nil, nil] if filter_string.blank?
        f = filter_string.to_s.strip

        # Pfad 1: Branch-Match (STI: Discipline.where(type: 'Branch'))
        branch = Branch.find_by("name ILIKE ?", f)
        if branch
          discipline_ids = Discipline.where(super_discipline_id: branch.id).pluck(:id)
          return [discipline_ids, branch.name] if discipline_ids.any?
        end

        # Pfad 2: Discipline-Match
        discipline = Discipline.find_by("name ILIKE ?", f)
        return [[discipline.id], nil] if discipline

        # Pfad 3: numerische Discipline-ID
        if f.match?(/\A\d+\z/) && Discipline.exists?(f.to_i)
          return [[f.to_i], nil]
        end

        [nil, nil]
      rescue => e
        Rails.logger.warn "[BaseTool.resolve_discipline_or_branch] #{e.class}: #{e.message}"
        [nil, nil]
      end

      # Plan 14-G.2 / D-14-G4 + D-14-G5: Authority-Helper für Write-Tools.
      # Konsumiert Pundit-TournamentPolicy (4 Methoden aus 14-G.1).
      # Returnt nil bei Allow, error(...)-Response bei Denial.
      #
      # Usage in 14-G.4-Write-Tools (1-Zeilen-Pattern):
      #   return err if (err = authorize!(action: :update_deadline, tournament: ml.tournament, server_context: server_context))
      #
      # Boundary: KEINE Tool-Code-Edits in 14-G.2 (14-G.4-Scope) — Helper steht bereit.
      ALLOWED_AUTHORITY_ACTIONS = %i[assign_leiter update_deadline manage_teilnehmerliste enter_results].freeze

      def self.authorize!(action:, tournament:, server_context:)
        unless ALLOWED_AUTHORITY_ACTIONS.include?(action.to_sym)
          return error("Authority-Check: Action '#{action}' unbekannt; erlaubt: #{ALLOWED_AUTHORITY_ACTIONS.join(", ")}")
        end
        return error("Authority-Check: tournament-Argument fehlt") if tournament.nil?

        user_id = server_context&.dig(:user_id)
        return error("Authority-Check: nicht authentifiziert (kein server_context[:user_id])") if user_id.blank?

        user = User.find_by(id: user_id)
        return error("Authority-Check: User mit id=#{user_id} nicht gefunden (Token-Stale?)") if user.nil?

        policy = TournamentPolicy.new(user, tournament)
        if policy.public_send("#{action}?")
          nil # Allow
        else
          reasons = []
          reasons << "TL-Status=#{tournament.leiter?(user) ? "ja" : "nein"}"
          reasons << "Sportwart-Wirkbereich=#{user.in_sportwart_scope?(tournament) ? "ja" : "nein"}"
          error(
            "Authority-Denied: User-Id=#{user.id} hat KEIN '#{action}'-Recht " \
            "für Tournament-Id=#{tournament.id} (#{reasons.join("; ")})"
          )
        end
      rescue => e
        Rails.logger.warn "[BaseTool.authorize!] #{e.class}: #{e.message}"
        error("Authority-Check fehlgeschlagen (defensive): #{e.class.name}")
      end

      # Plan 14-G.4 / F5-A: Tournament-Resolver für Authority-Integration in Write-Tools.
      # Sucht Tournament-Record via RegistrationListCc-Chain (wenn meldeliste_cc_id gegeben;
      # die "Meldeliste" in CC entspricht RegistrationListCc in Carambus-DB)
      # ODER TournamentCc-Chain (wenn tournament_cc_id gegeben).
      # Defensiv: returnt nil bei unauflöslichen Inputs (kein Crash).
      def self.resolve_tournament(meldeliste_cc_id: nil, tournament_cc_id: nil, server_context: nil)
        context = effective_cc_region(server_context).to_s.downcase
        return nil if context.blank?

        if meldeliste_cc_id.present?
          rlc = RegistrationListCc.find_by(cc_id: meldeliste_cc_id.to_i, context: context)
          if rlc
            tcc = TournamentCc.find_by(registration_list_cc_id: rlc.id, context: context)
            return tcc.tournament if tcc&.tournament
          end
        end

        if tournament_cc_id.present?
          tcc = TournamentCc.find_by(cc_id: tournament_cc_id.to_i, context: context)
          return tcc.tournament if tcc&.tournament
        end

        nil
      rescue => e
        Rails.logger.warn "[BaseTool.resolve_tournament] #{e.class}: #{e.message}"
        nil
      end
    end
  end
end
