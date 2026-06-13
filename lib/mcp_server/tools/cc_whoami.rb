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
                  "sportwart_disciplines: [...], personas: [...], can_write_cc: bool }. " \
                  "Keine sensitiven Felder; idempotent; read-only."
      input_schema(properties: {})
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(server_context: nil)
        payload = {
          scenario_name: resolve_scenario_name,
          region: resolve_region,
          default_season: resolve_default_season(server_context),
          user: resolve_user_envelope(server_context),
          sportwart_locations: resolve_sportwart_locations(server_context),
          sportwart_disciplines: resolve_sportwart_disciplines(server_context),
          personas: resolve_personas(server_context),
          can_write_cc: resolve_can_write_cc(server_context)
        }
        text(JSON.generate(payload))
      rescue => e
        Rails.logger.warn "[CcWhoami.call] #{e.class}: #{e.message}"
        error("cc_whoami exception: #{e.class.name} (details suppressed; check Rails.logger).")
      end

      # Scenario-Name. Resolution-Kette (Plan-22-01-Bugfix nach Pre-Apply-Verify):
      # 1. ENV["scenarioname"] (Capistrano whenever_variables-set für Cron-Jobs)
      # 2. ENV["SCENARIO_NAME"] (manual override)
      # 3. Carambus.config.basename (Scenario-Config = die kanonische Quelle —
      #    carambus_nbv hat basename: "carambus_nbv", carambus_api hat "carambus_api" etc.)
      # 4. Rails.application.class.module_parent_name.underscore
      #    (Fallback — liefert "carambus_app" o.ä. weil alle Scenarios dasselbe
      #    Rails-Application-Modul teilen; NUR als letzter Strohhalm)
      def self.resolve_scenario_name
        ENV["scenarioname"].presence ||
          ENV["SCENARIO_NAME"].presence ||
          (Carambus.config.basename.presence if Carambus.config.respond_to?(:basename)) ||
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
        envelope = {id: u.id, email: u.email}
        envelope[:first_name] = u.first_name if u.first_name.present?
        # D-35/D-38: verknuepften Player (current_user.player) exposen, damit der Chat die echte
        # Person kennt (Name + Verein) und den Nutzer mit seinem Spieler-Namen ansprechen kann.
        if (player = u.player)
          envelope[:player] = {
            id: player.id,
            firstname: player.firstname,
            lastname: player.lastname,
            fullname: player.fullname,
            club: player.club&.shortname
          }.compact
        end
        envelope
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

      # Sportwart-Disciplines mit branch_cc_id (CC admin branch ID für Tool-Calls wie
      # cc_lookup_meldeliste_for_tournament). branch_cc_id aus BranchCc-Lookup per
      # discipline_id + context — nil wenn kein BranchCc-Eintrag existiert.
      def self.resolve_sportwart_disciplines(server_context)
        user_id = server_context&.dig(:user_id)
        return [] if user_id.blank?
        u = User.find_by(id: user_id)
        return [] unless u&.respond_to?(:sportwart_disciplines)
        ctx = Carambus.config.context.to_s.presence
        u.sportwart_disciplines.map do |d|
          branch_cc_id = BranchCc.find_by(discipline_id: d.id, context: ctx)&.cc_id
          {id: d.id, name: d.name, branch_cc_id: branch_cc_id}
        end
      rescue => e
        Rails.logger.warn "[CcWhoami.resolve_sportwart_disciplines] #{e.class}: #{e.message}"
        []
      end

      # Abgeleitete Personas des Users (UserPersonas-Concern, Phase 34-01):
      # z.B. ["player"] / ["player","sportwart"] / ["club_admin","turnierleiter"].
      def self.resolve_personas(server_context)
        user_id = server_context&.dig(:user_id)
        return [] if user_id.blank?
        u = User.find_by(id: user_id)
        return [] unless u&.respond_to?(:personas)
        u.personas.map(&:to_s)
      rescue => e
        Rails.logger.warn "[CcWhoami.resolve_personas] #{e.class}: #{e.message}"
        []
      end

      # CC-Schreibrecht der Persona (34-01 cc_write_access?): true für Sportwart/TL/Admin.
      def self.resolve_can_write_cc(server_context)
        user_id = server_context&.dig(:user_id)
        return false if user_id.blank?
        u = User.find_by(id: user_id)
        return false unless u&.respond_to?(:cc_write_access?)
        u.cc_write_access?
      rescue => e
        Rails.logger.warn "[CcWhoami.resolve_can_write_cc] #{e.class}: #{e.message}"
        false
      end
    end
  end
end
