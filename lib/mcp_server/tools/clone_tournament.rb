# frozen_string_literal: true

# cc_clone_tournament — v1.3 Phase 50 (Weg 3): klont ein Vorsaison-Turnier in die
# Folgesaison NUR in ClubCloud (nbv-CC-Write). Delegiert an
# TournamentPreparation::TournamentCloner (Datum +1 Jahr/nächster gleicher Wochentag,
# Spielort + Format EXAKT aus der Quelle, Meldeliste leer).
#
# ZWEISTUFIGE Bestätigung (Release = Point of no Return):
#   armed:false            → Dry-Run (Plan, keine CC-Mutation)
#   armed:true             → Meldeliste anlegen (REVERSIBEL/löschbar), Meisterschaft SKIP
#   armed:true release:true → Meldeliste FREIGEBEN (IRREVERSIBEL) + verborgene, gebundene Meisterschaft
module McpServer
  module Tools
    class CloneTournament < BaseTool
      tool_name "cc_clone_tournament"
      description <<~DESC
        Wann nutzen? Wenn der Landessportwart ein Turnier der Vorsaison in die neue Saison übernehmen will — Meldeliste + Meisterschaft werden in ClubCloud angelegt (Datum +1 Jahr auf den nächsten gleichen Wochentag; Spielort + Format exakt aus der Quelle; Meldeliste leer).
        Was tippt der User typisch? 'Klone das NDM-Cadre-Turnier in die neue Saison', 'Übernimm das Vorsaison-Turnier X für 2026/2027'.
        ⚠️ ZWEI Stufen: `armed:true` legt die Meldeliste an (REVERSIBEL/löschbar). Erst `armed:true, release:true` gibt die Meldeliste FREI (IRREVERSIBEL — freigegebene Meldelisten sind nicht mehr löschbar, nur umbenennbar) und legt die verborgene, gebundene Meisterschaft an.
        `armed:false` (Default) = Dry-Run (zeigt den Plan, keine CC-Mutation).
        **Rufe dieses Tool DIREKT auf — suche NICHT vorher selbst nach dem Turnier.** Gib einfach den Turnier-Titel als `source_title` an; das Tool findet das Vorsaison-Turnier selbst (region-scoped). Alternativ `source_tournament_cc_id`. Wenn das Tool „nicht gefunden" meldet, frage den genauen Titel/die Saison nach — verweise NIE auf die ClubCloud-Oberfläche als Ersatz.
      DESC
      input_schema(
        properties: {
          source_tournament_cc_id: {type: "integer", description: "CC meisterschaftsId des Vorsaison-Quell-Turniers (falls bekannt). Entweder dies oder source_title."},
          source_title: {type: "string", description: "Titel des Vorsaison-Turniers (z.B. '1.Grand Prix FP') — einfachster Weg; das Tool löst ihn region-scoped auf (Fehler nur bei Mehrdeutigkeit). Entweder dies oder source_tournament_cc_id."},
          target_season: {type: "string", description: "Optional: Ziel-Saison 'yyyy/yyyy+1' (Default: Folgesaison der Quelle)."},
          armed: {type: "boolean", default: false, description: "false (Default) = Dry-Run. true = legt die Meldeliste an (reversibel)."},
          release: {type: "boolean", default: false, description: "Nur zusammen mit armed:true. true = gibt die Meldeliste FREI (IRREVERSIBEL) und legt die verborgene Meisterschaft an."}
        }
      )
      annotations(read_only_hint: false, destructive_hint: true)

      def self.call(source_tournament_cc_id: nil, source_title: nil, target_season: nil,
        armed: false, release: false, server_context: nil)
        source = resolve_source(source_tournament_cc_id, source_title, server_context)
        return source if source.is_a?(MCP::Tool::Response) # error envelope
        return error("Quell-Turnier nicht gefunden — source_tournament_cc_id oder source_title prüfen.") unless source

        auth_err = authorize!(action: :prepare_tournament, tournament: source, server_context: server_context)
        return auth_err if auth_err

        account = resolve_cc_account(tournament: source, server_context: server_context)
        identity_block = cc_write_identity_block(account, armed: armed)
        return identity_block if identity_block

        ts = target_season.present? ? Season.find_by_name(target_season) : source.season&.next_season
        return error("Ziel-Saison nicht ermittelbar (target_season=#{target_season.inspect}).") unless ts

        opts = armed ? {session_id: cc_session.cookie_for(account)} : {}
        result = TournamentPreparation::TournamentCloner.call(
          source_tournament: source, armed: armed, release: release, target_season: ts, opts: opts
        )

        unless armed
          return text(<<~DRY.strip)
            [DRY-RUN] Klon-Plan für '#{source.title}' → Saison #{result[:target_season]}:
            Datum: #{source.date&.strftime("%Y-%m-%d")} → #{result[:new_start]} (+1 Jahr, nächster gleicher Wochentag)
            Meldeliste: '#{result.dig(:meldeliste_args, :meldelistenName)}' (Kategorie-cc_id #{result[:selected_cat_id]}), leer.
            Meisterschaft: Spielort '#{result.dig(:meisterschaft_args, :pubName)}', gebunden an die neue Meldeliste.
            Nächste Schritte: armed:true → Meldeliste (reversibel); dann armed:true + release:true → FREIGABE (IRREVERSIBEL) + Meisterschaft.
          DRY
        end

        McpServer::AuditTrail.write_entry(
          tool_name: "cc_clone_tournament",
          operator: cc_audit_operator,
          payload: {source_tournament_id: source.id, target_season: result[:target_season],
                    armed: armed, release: release,
                    meldeliste_cc_id: result[:meldeliste_cc_id], meisterschaft_cc_id: result[:meisterschaft_cc_id]},
          pre_validation_results: [],
          read_back_status: result[:meisterschaft_status].to_s,
          result: "success",
          user_id: account.acting_user_id
        )

        if release
          text(<<~OUT.strip)
            Turnier '#{source.title}' geklont → Saison #{result[:target_season]}.
            Meldeliste cc_id=#{result[:meldeliste_cc_id]} (Status: #{result[:meldeliste_status]}), Meisterschaft cc_id=#{result[:meisterschaft_cc_id]}.
            #{result[:meisterschaft_status]}
          OUT
        else
          text(<<~OUT.strip)
            Meldeliste für '#{source.title}' angelegt (cc_id=#{result[:meldeliste_cc_id]}, Status: #{result[:meldeliste_status]}) — REVERSIBEL/noch löschbar.
            Zum Finalisieren (Freigabe IRREVERSIBEL + Meisterschaft + Verbergen): erneut mit release:true aufrufen.
            #{result[:meisterschaft_status]}
          OUT
        end
      rescue => e
        Rails.logger.warn "[cc_clone_tournament] #{e.class}: #{e.message}"
        error("Tool-Exception: #{e.class.name} (Details im Rails-Log).")
      end

      # Quelle auflösen: cc_id (resolve_tournament, context-scoped) oder Titel (context+name).
      def self.resolve_source(cc_id, title, server_context)
        if cc_id.present?
          t = resolve_tournament(tournament_cc_id: cc_id, server_context: server_context)
          return t if t
        end
        if title.present?
          context = effective_cc_region(server_context).to_s.downcase
          return nil if context.blank?
          tournaments = TournamentCc.where(context: context, name: title).filter_map(&:tournament).uniq
          return error("Mehrdeutiger Titel '#{title}' (#{tournaments.size} Treffer) — bitte source_tournament_cc_id nutzen.") if tournaments.size > 1
          return tournaments.first
        end
        nil
      end
    end
  end
end
