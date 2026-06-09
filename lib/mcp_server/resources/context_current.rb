# frozen_string_literal: true

# ContextCurrent — Phase 22-01 Foundation Resource (D-22-DISC-A).
#
# MCP-Resource cc://context/current liefert die Minimal-Form des Server-Kontexts
# (analog cc_whoami-Tool, aber ohne user-spezifische Felder, weil Resource-Read
# typischerweise ohne Auth-Token läuft).
#
# Plan-01 zentraler read_handler in server.rb dispatcht cc://context/current → .read(uri:).
# Diese Klasse stellt nur .all + .read(uri:) bereit (KOEXISTENZ-Pattern wie WorkflowMeta).
#
# Konsistenz mit cc_whoami: identische Schlüssel-Namen + identische Sub-Struktur für
# scenario_name + region + default_season. Felder user/sportwart_locations/sportwart_disciplines
# sind hier IMMER nil/[] — für authentifizierte user-Sicht muss der Caller cc_whoami als Tool
# rufen (das hat Zugriff auf server_context).

module McpServer
  module Resources
    class ContextCurrent
      URI = "context://current"

      def self.all
        [
          MCP::Resource.new(
            uri: URI,
            name: "context-current",
            title: "Carambus MCP Server Context (current session)",
            description: "Read-only snapshot of the active server context: scenario_name " \
                         "(which Local-Server), region (Carambus.config.context-resolved, " \
                         "can be nil for cross-region scenarios), default_season. " \
                         "For user-scoped fields (sportwart_locations/sportwart_disciplines), " \
                         "call the cc_whoami tool instead — Resource-Read has no auth-context.",
            mime_type: "application/json"
          )
        ]
      end

      # Wird vom zentralen Read-Handler in server.rb aufgerufen.
      # Returns Hash {content:, mime_type:} für normalize_resource_result-Kompatibilität.
      def self.read(uri:)
        payload = {
          scenario_name: McpServer::Tools::CcWhoami.resolve_scenario_name,
          region: McpServer::Tools::CcWhoami.resolve_region,
          default_season: McpServer::Tools::CcWhoami.resolve_default_season(nil),
          user: nil,
          sportwart_locations: [],
          sportwart_disciplines: []
        }
        {content: JSON.generate(payload), mime_type: "application/json"}
      rescue => e
        Rails.logger.warn "[ContextCurrent.read] #{e.class}: #{e.message}"
        {content: JSON.generate(error: "context://current resource exception: #{e.class.name}"), mime_type: "application/json"}
      end
    end
  end
end
