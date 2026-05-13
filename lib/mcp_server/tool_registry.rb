# frozen_string_literal: true

require_relative "role_tool_map"

module McpServer
  # Public API für Tool-Subset-Auflösung pro User.
  # Plan 13-03 (McpController) wird `ToolRegistry.tools_for(current_user)` als Server-Tools-Liste verwenden.
  # Plan 13-04 (server_context-Propagation) braucht ToolRegistry NICHT direkt — Tools sind dann schon gefiltert.
  module ToolRegistry
    # Liefert Array von Tool-Klassen-Symbolen für den User.
    # Defensive: nil-User oder unbekannte Rolle → leeres Array (keine Tools verfügbar).
    def self.tools_for(user)
      return [] if user.nil?

      role_key = user.mcp_role&.to_sym
      return [] unless role_key

      RoleToolMap::MAPPING[role_key] || []
    end

    # Anzahl Tools für eine Rolle. Für Test-Assertions + Audit-Logging.
    def self.tool_count_for(role_key)
      return 0 if role_key.nil?

      RoleToolMap::EXPECTED_COUNTS[role_key.to_sym] || 0
    end

    # Resolved Tool-Klassen (statt nur Symbole) — für Plan 13-03 McpController-Mount.
    # Lookup via "McpServer::Tools::#{name}".constantize.
    def self.tool_classes_for(user)
      tools_for(user).map do |sym|
        "McpServer::Tools::#{sym}".constantize
      rescue NameError => e
        Rails.logger.warn("ToolRegistry: unknown tool class #{sym}: #{e.message}")
        nil
      end.compact
    end
  end
end
