# frozen_string_literal: true

# cc_assign_tournament_leiter — Phase 34-04 (D-34-5).
# Ordnet einen Carambus-Nutzer als Turnierleiter eines Turniers zu — als LOKALE
# Carambus-Zuordnung (UserTournament, role: turnier_leiter), KEIN ClubCloud-Eintrag.
# Gated via TournamentPolicy#assign_leiter? (admin ODER Sportwart-im-Wirkbereich).
# armed-Muster: Default Dry-Run; armed:true schreibt. Schreibt NIE das globale
# Tournament.turnier_leiter_user_id (Union-Modell, D-34-5).
module McpServer
  module Tools
    class AssignTournamentLeiter < BaseTool
      tool_name "cc_assign_tournament_leiter"
      description <<~DESC
        Wann nutzen? Wenn ein Sportwart einen Carambus-Nutzer als Turnierleiter eines Turniers benennen will ("mach Max Mueller zum Turnierleiter des Cadre-Turniers").
        Was tippt der User typisch? "Turnierleiter fuer DM Cadre: Max Mueller", "Setze Anna Schmidt als Leiterin des Eurokegel ein".
        Dies ist eine INTERNE Carambus-Zuordnung (KEIN ClubCloud-Eintrag). Der kuenftige Turnierleiter braucht ein Carambus-Benutzerkonto.
        Gib das Turnier via tournament_cc_id und den kuenftigen Leiter via leiter_email ODER leiter_name an.
        armed:false (Default) = Probelauf ohne Aenderung; armed:true fuehrt die Zuordnung durch.
      DESC
      input_schema(
        properties: {
          tournament_cc_id: {type: "integer", description: "ClubCloud-ID des Turniers (tournament_cc.cc_id)."},
          leiter_email: {type: "string", description: "Optional: Email/Benutzername des kuenftigen Turnierleiters (exakt). Entweder dies oder leiter_name."},
          leiter_name: {type: "string", description: "Optional: Name des kuenftigen Turnierleiters (Token-Suche). Entweder dies oder leiter_email."},
          armed: {type: "boolean", default: false, description: "false (Default) = Probelauf; true = Zuordnung durchfuehren."}
        },
        required: ["tournament_cc_id"]
      )
      annotations(read_only_hint: false, destructive_hint: true)

      def self.call(tournament_cc_id: nil, leiter_email: nil, leiter_name: nil, armed: false, server_context: nil)
        err = validate_required!({tournament_cc_id: tournament_cc_id}, [:tournament_cc_id])
        return err if err

        tournament = resolve_tournament(tournament_cc_id: tournament_cc_id, server_context: server_context)
        return error("Turnier zu dieser Kennung nicht gefunden (in dieser Region).") if tournament.nil?

        user, uerr = resolve_tl_user(email: leiter_email, name: leiter_name, server_context: server_context)
        return uerr if uerr

        auth_err = authorize!(action: :assign_leiter, tournament: tournament, server_context: server_context)
        return auth_err if auth_err

        if tournament.leiter?(user)
          return text("#{user.display_name} ist bereits Turnierleiter dieses Turniers (#{tournament.title}).")
        end

        unless armed
          return text("[Probelauf] Wuerde #{user.display_name} als Turnierleiter von '#{tournament.title}' zuordnen. Mit armed:true durchfuehren.")
        end

        UserTournament.find_or_create_by!(user: user, tournament: tournament, role: "turnier_leiter")

        McpServer::AuditTrail.write_entry(
          tool_name: "cc_assign_tournament_leiter",
          operator: User.find_by(id: server_context&.dig(:user_id))&.email || "unknown",
          payload: {tournament_id: tournament.id, user_id: user.id, role: "turnier_leiter"},
          pre_validation_results: [],
          read_back_status: "n/a",
          result: "success",
          user_id: server_context&.dig(:user_id)
        )

        text("#{user.display_name} ist jetzt Turnierleiter von '#{tournament.title}'.")
      rescue => e
        Rails.logger.warn "[AssignTournamentLeiter.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end
    end
  end
end
