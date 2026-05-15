# frozen_string_literal: true

require_relative "role_tool_map"

module McpServer
  # TEMPORARY STUB (Plan 14-G.1 / D-14-G6):
  # User#mcp_role-Enum wurde entfernt; jeder authentifizierte User bekommt das
  # volle Tool-Subset. Authority-Layer-Refactor (Sportwart-Wirkbereich + TL-FK +
  # Carambus.config.region_id) folgt in Plan 14-G.2.
  module ToolRegistry
    # Liefert Array von Tool-Klassen-Symbolen für den User.
    # Stub-Verhalten: jeder nicht-nil User bekommt ALL_TOOLS.
    def self.tools_for(user)
      return [] if user.nil?
      RoleToolMap::ALL_TOOLS
    end

    # Anzahl Tools für eine "Rolle" — Stub gibt für jeden Key die ALL_TOOLS-Größe zurück.
    # Wird in 14-G.2 wieder authority-basiert (Sportwart vs TL vs LSW Tool-Subsets).
    def self.tool_count_for(_role_key)
      RoleToolMap::ALL_TOOLS.size
    end

    # Resolved Tool-Klassen (statt nur Symbole) — für McpController-Mount.
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
