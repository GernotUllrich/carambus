# frozen_string_literal: true

# cc_link_my_player — Phase 35-01 (D-35-1/2).
# Self-Service: verknuepft den EINGELOGGTEN Nutzer mit SEINEM Spielerprofil ueber die
# DBU-Nummer (region-scoped) oder BA-ID (Fallback). Setzt users.player_id (eigenes Profil,
# KEINE ClubCloud-Aktion, kein fremder User). Voraussetzung fuer "Mein Billard" (35-02).
# Registry-Stufe: SELF_SERVICE_TOOLS (fuer alle authentifizierten User).
module McpServer
  module Tools
    class LinkMyPlayer < BaseTool
      tool_name "cc_link_my_player"
      description <<~DESC
        Wann nutzen? Wenn DU (eingeloggter Nutzer) dein Carambus-Konto mit deinem Spielerprofil verknuepfen willst — Voraussetzung, um deine eigenen Turniere, Ergebnisse und deine Rangliste zu sehen.
        Was tippt der User typisch? "Verknuepfe mich, DBU-Nummer 12345", "Ich bin Spieler mit DBU 98765".
        Self-Service: setzt NUR dein eigenes Profil (keine ClubCloud-Aktion, kein anderer Nutzer).
        Gib deine DBU-Nummer (dbu_nr) an; alternativ deine aeltere BA-ID (ba_id).
        armed:false (Default) = Probelauf (zeigt den gefundenen Spieler); armed:true = verknuepfen.
      DESC
      input_schema(
        properties: {
          dbu_nr: {type: "integer", description: "Deine DBU-Mitgliedsnummer (offizieller Ausweis)."},
          ba_id: {type: "integer", description: "Optional: aeltere BA-ID (Fallback, falls keine DBU-Nummer)."},
          armed: {type: "boolean", default: false, description: "false (Default) = Probelauf; true = verknuepfen."}
        }
      )
      annotations(read_only_hint: false, destructive_hint: false)

      def self.call(dbu_nr: nil, ba_id: nil, armed: false, server_context: nil)
        user = User.find_by(id: server_context&.dig(:user_id))
        return error("Nicht angemeldet — Verknuepfung nicht moeglich.") if user.nil?

        player, perr = resolve_own_player(dbu_nr: dbu_nr, ba_id: ba_id, server_context: server_context)
        return perr if perr

        if user.player_id == player.id
          return text("Du bist bereits mit deinem Spielerprofil (#{player.fullname}) verknuepft.")
        end

        other = User.where.not(id: user.id).find_by(player_id: player.id)
        if other
          return error("Dieses Spielerprofil (#{player.fullname}) ist bereits mit einem anderen Konto verknuepft. Bitte wende dich an den Administrator, falls das ein Fehler ist.")
        end

        unless armed
          return text("[Probelauf] Wuerde dich mit #{player.fullname} verknuepfen. Mit armed:true bestaetigen.")
        end

        user.update!(player_id: player.id)

        McpServer::AuditTrail.write_entry(
          tool_name: "cc_link_my_player",
          operator: user.email,
          payload: {user_id: user.id, player_id: player.id},
          pre_validation_results: [],
          read_back_status: "n/a",
          result: "success",
          user_id: user.id
        )

        text("Verknuepft: Du bist jetzt mit deinem Spielerprofil #{player.fullname} verbunden.")
      rescue => e
        Rails.logger.warn "[LinkMyPlayer.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end
    end
  end
end
