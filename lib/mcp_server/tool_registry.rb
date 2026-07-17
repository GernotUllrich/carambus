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
      tools.concat(RoleToolMap::SELF_SERVICE_TOOLS)
      # CC-Write-Tools NUR auf Local-Servern. Auf der Authority (api.carambus.de, carambus_api_url
      # blank) liefen Schreibaktionen unter der geteilten Scraper-/Admin-Identität (fehl-attribuiert
      # in der CC) + umgehen das Per-User-/Scope-Modell (Phase 39). Authority-Chat = read-only —
      # auch für system_admin. Turnierverwaltung gehört auf die Local-Server.
      tools.concat(RoleToolMap::WRITE_TOOLS) if user.cc_write_access? && local_server?
      tools.uniq
    end

    # Authority (zentrale API/Scraper) hat KEINE carambus_api_url; Local-Server haben eine.
    def self.local_server?
      Carambus.config.carambus_api_url.present?
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
