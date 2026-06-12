# frozen_string_literal: true

# cc_remove_tournament_leiter — Phase 34-04 (D-34-5).
# Entfernt eine LOKALE Turnierleiter-Zuordnung (UserTournament, role: turnier_leiter).
# Globale Zuordnungen (Tournament.turnier_leiter_user_id, ueber das Turnier-Formular
# gesetzt) werden NICHT angefasst — klare Ablehnung (Union-Modell, D-34-5).
# Gated via TournamentPolicy#assign_leiter?. armed-Muster.
module McpServer
  module Tools
    class RemoveTournamentLeiter < BaseTool
      tool_name "cc_remove_tournament_leiter"
      description <<~DESC
        Wann nutzen? Wenn eine im Chat gesetzte Turnierleiter-Zuordnung wieder entfernt werden soll ("entferne Max Mueller als Turnierleiter des Cadre-Turniers").
        Entfernt NUR lokal (im Chat) gesetzte Zuordnungen. Eine ueber das Turnier-Formular gesetzte Zuordnung kann hier NICHT entfernt werden — dann bitte im Turnier-Formular aendern.
        Gib tournament_cc_id + leiter_email ODER leiter_name an. armed:false (Default) = Probelauf.
      DESC
      input_schema(
        properties: {
          tournament_cc_id: {type: "integer", description: "ClubCloud-ID des Turniers (tournament_cc.cc_id)."},
          leiter_email: {type: "string", description: "Optional: Email/Benutzername des Turnierleiters. Entweder dies oder leiter_name."},
          leiter_name: {type: "string", description: "Optional: Name des Turnierleiters (Token-Suche). Entweder dies oder leiter_email."},
          armed: {type: "boolean", default: false, description: "false (Default) = Probelauf; true = entfernen."}
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

        ut = UserTournament.find_by(user: user, tournament: tournament, role: "turnier_leiter")

        if ut.nil?
          if tournament.turnier_leiter_user_id == user.id
            return error("Die Turnierleiter-Zuordnung von #{user.display_name} stammt aus dem Turnier-Formular (globale Zuordnung) und kann hier nicht entfernt werden — bitte im Turnier-Formular aendern.")
          end
          return text("#{user.display_name} ist nicht als Turnierleiter dieses Turniers zugeordnet.")
        end

        unless armed
          return text("[Probelauf] Wuerde #{user.display_name} als Turnierleiter von '#{tournament.title}' entfernen. Mit armed:true durchfuehren.")
        end

        ut.destroy!

        McpServer::AuditTrail.write_entry(
          tool_name: "cc_remove_tournament_leiter",
          operator: User.find_by(id: server_context&.dig(:user_id))&.email || "unknown",
          payload: {tournament_id: tournament.id, user_id: user.id, role: "turnier_leiter"},
          pre_validation_results: [],
          read_back_status: "n/a",
          result: "success",
          user_id: server_context&.dig(:user_id)
        )

        text("#{user.display_name} ist nicht mehr Turnierleiter von '#{tournament.title}'.")
      rescue => e
        Rails.logger.warn "[RemoveTournamentLeiter.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end
    end
  end
end
