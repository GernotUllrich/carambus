# frozen_string_literal: true

# cc_whoami — Phase 22-01 Foundation (D-22-DISC-A/B/D + Memory project_mcp_endpoint_per_persona_local_server).
#
# Liefert den aktiven Server-Kontext einer MCP-Session: scenario_name (welcher Local-Server),
# region (Carambus.config.context-Lookup, kann nil sein für carambus-Scenario ohne Region-Filter),
# default_season, plus user-spezifisch sportwart_locations + sportwart_disciplines.
#
# Use BEFORE any other tool to learn the active scope — eliminates "dumme Rückfragen" wie
# „Welche cc_id für den Verein?" bei Regionsmeisterschaften. Pendant-Resource: context://current
# (server.rb dispatcht; minimal-Form ohne user-Scope für Resource-Read ohne Auth).
#
# Bewusst KEINE sensitiven Felder im Output: keine encrypted_cc_credentials, kein password_digest,
# kein JWT-Token-Inhalt. Plus: für carambus-Scenario (context nil) returns region: nil — auch das
# ist legitime Server-Information.

module McpServer
  module Tools
    class CcWhoami < BaseTool
      tool_name "cc_whoami"
      description "Wann nutzen? Als ersten Tool-Call in einer MCP-Session — der Server " \
                  "kommuniziert hier seinen aktiven Kontext (scenario_name, region, " \
                  "default_season + Sportwart-Wirkbereich des authentifizierten Users). " \
                  "Was tippt der User typisch? Selten direkt — der LLM-Caller sollte cc_whoami " \
                  "automatisch zu Sessionbeginn aufrufen (siehe server.instructions). " \
                  "Returns: { scenario_name, region: {shortname, name, cc_id} | nil, " \
                  "default_season, user: {id, email} | nil, sportwart_locations: [...], " \
                  "sportwart_disciplines: [...] }. Keine sensitiven Felder; idempotent; read-only."
      input_schema(properties: {})
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(server_context: nil)
        payload = {
          scenario_name: resolve_scenario_name,
          region: resolve_region,
          default_season: resolve_default_season(server_context),
          user: resolve_user_envelope(server_context),
          sportwart_locations: resolve_sportwart_locations(server_context),
          sportwart_disciplines: resolve_sportwart_disciplines(server_context)
        }
        text(JSON.generate(payload))
      rescue => e
        Rails.logger.warn "[CcWhoami.call] #{e.class}: #{e.message}"
        error("cc_whoami exception: #{e.class.name} (details suppressed; check Rails.logger).")
      end

      # Scenario-Name aus ENV (Capistrano whenever_variables setzt `scenarioname`),
      # mit Fallback auf SCENARIO_NAME oder Rails-Application-Module-Name.
      def self.resolve_scenario_name
        ENV["scenarioname"].presence ||
          ENV["SCENARIO_NAME"].presence ||
          begin
            Rails.application.class.module_parent_name.underscore
          rescue
            "unknown"
          end
      end

      # Region aus Carambus.config.context (Scenario-Config-Key); nil-tolerant für
      # carambus-Scenario, das keinen Region-Filter hat (User-Befund 2026-05-30).
      def self.resolve_region
        ctx = begin
          Carambus.config.context.to_s
        rescue
          ""
        end
        return nil if ctx.blank?
        r = Region.find_by("LOWER(shortname) = ?", ctx.downcase)
        return nil unless r
        {shortname: r.shortname, name: r.name, cc_id: r.cc_id}
      rescue => e
        Rails.logger.warn "[CcWhoami.resolve_region] #{e.class}: #{e.message}"
        nil
      end

      # Default-Season aus Season.current_season (oder Carambus.config.season_name als Fallback).
      def self.resolve_default_season(server_context)
        begin
          effective_season(server_context)&.name
        rescue
          nil
        end ||
          begin
            Carambus.config.season_name
          rescue
            nil
          end
      end

      # User-Envelope: nur id + email — bewusst KEINE sensitiven Felder.
      def self.resolve_user_envelope(server_context)
        user_id = server_context&.dig(:user_id)
        return nil if user_id.blank?
        u = User.find_by(id: user_id)
        return nil unless u
        {id: u.id, email: u.email}
      rescue => e
        Rails.logger.warn "[CcWhoami.resolve_user_envelope] #{e.class}: #{e.message}"
        nil
      end

      # Sportwart-Locations aus User-Token. Felder location_ids + names — keine sonstigen
      # Location-Attribute (no leak von Adresse/Telefon/etc.).
      def self.resolve_sportwart_locations(server_context)
        user_id = server_context&.dig(:user_id)
        return [] if user_id.blank?
        u = User.find_by(id: user_id)
        return [] unless u&.respond_to?(:sportwart_locations)
        u.sportwart_locations.pluck(:id, :name).map { |id, name| {id: id, name: name} }
      rescue => e
        Rails.logger.warn "[CcWhoami.resolve_sportwart_locations] #{e.class}: #{e.message}"
        []
      end

      # Sportwart-Disciplines analog.
      def self.resolve_sportwart_disciplines(server_context)
        user_id = server_context&.dig(:user_id)
        return [] if user_id.blank?
        u = User.find_by(id: user_id)
        return [] unless u&.respond_to?(:sportwart_disciplines)
        u.sportwart_disciplines.pluck(:id, :name).map { |id, name| {id: id, name: name} }
      rescue => e
        Rails.logger.warn "[CcWhoami.resolve_sportwart_disciplines] #{e.class}: #{e.message}"
        []
      end
    end
  end
end
