# frozen_string_literal: true

require_relative "role_tool_map"

module McpServer
  # Persona-basiertes Tool-Gating (Phase 34-01, v1.0):
  # Jeder authentifizierte User bekommt die Read-Tools; CC-Write-Tools nur, wenn
  # user.cc_write_access? (Sportwart + Turnierleiter + system_admin). Per-Record-
  # Authority bleibt orthogonal in BaseTool.authorize! (TournamentPolicy) —
  # das Tier-Gating hier ist Defense-in-Depth davor.
  module ToolRegistry
    # Liefert Array von Tool-Klassen-Symbolen für den User, persona-gefiltert.
    def self.tools_for(user)
      return [] if user.nil?
      tools = RoleToolMap::BASE_READ_TOOLS.dup
      tools.concat(RoleToolMap::WRITE_TOOLS) if user.cc_write_access?
      tools.uniq
    end

    # Anzahl Tools, die der User tatsächlich bekommt (persona-gefiltert).
    def self.tool_count_for(user)
      tools_for(user).size
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
