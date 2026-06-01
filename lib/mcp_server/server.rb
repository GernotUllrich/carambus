# frozen_string_literal: true

# Server-Wiring: instanziiert MCP::Server, registriert alle McpServer::Tools::* Subclasses
# automatisch via Zeitwerk-vorgeladene Konstanten + alle McpServer::Resources::* via Registry-Module.
#
# CRITICAL (per revision 2026-05-07 Blockers 2+3): The MCP SDK accepts ONE `resources_read_handler`
# block per server. Plan 01 owns this single handler; Plans 02 (workflow) + 03 (api_surface) ONLY
# expose `.read(slug:|action:, uri:)` class methods. They do NOT register their own handler.
# This makes Wave 2 conflict-free — no plan touches server.rb after Plan 01.

module McpServer
  class Server
    SERVER_NAME = "carambus_clubcloud"

    # Plan 22-01 T3: Top-Level-Anleitung für LLM-Caller. Wird beim MCP-Initialize-
    # Handshake an den Client gesendet (MCP-Protokoll-Version >= 2025-03-26).
    # Zweck: Caller weiß sofort, dass cc_whoami der First-Call sein soll —
    # eliminates "dumme Rückfragen" wie „Welche cc_id für den Verein?" bei
    # Regionsmeisterschaften (Wurzel W1 der Halluzinations-Episode 2026-05-31,
    # siehe Phase 22 CONTEXT.md). Plus DB-first-Hinweis + cc_id-region-Scope-
    # Warnung als Sicherheits-Anker für die 4 bare-cc_id-Lookups (Memory
    # project_cc_id_not_unique). Klares Phase-22-Permission-Modell statt
    # club_cc_id-Allowlist (Memory project_mcp_sportwart_scope_leaky_abstraction).
    SERVER_INSTRUCTIONS = <<~TXT.strip.freeze
      Welcome to the Carambus MCP Server.

      Use `cc_whoami` first (or read MCP Resource `context://current`) to learn
      your full session scope: region, sportwart_locations, sportwart_disciplines,
      default_season, and which Local-Server scenario you're connected to.

      Data primer:
      - All global Carambus data (regions, tournaments, players, meldelisten) is
        mirrored on this Local-Server via sync from the Authority — DB-first is
        primary; live-CC calls are only for writes or force-refresh.
      - `cc_id` (ClubCloud-ID) is REGION-SCOPED, not globally unique — context
        filter required for any cc_id-based lookup.
      - Tournament entity chain: Tournament (DB) → TournamentCc (CC-Mirror
        mit meldeliste_cc_id / meldeliste_deadline / meldeliste_qualifying_date
        direkt auf TCc; RegistrationListCc wurde in Phase 23 T1b ersatzlos
        gedroppt).

      Permission model (Phase 22+):
      - Your effective scope is `(sportwart_location_ids, sportwart_discipline_ids,
        region)` — not Club. Tools verify your scope server-side; you don't need
        to pass `club_cc_id` for region-wide tournaments.
    TXT

    # Build the server with auto-registered tools and resources.
    # Plans 02..05 add files; this method picks them up via constant enumeration.
    def self.build
      # Force-load tool subclass files so .constants enumeration is complete after autoload.
      eager_load_namespace!

      tools = collect_tools
      resources = collect_resources

      server = MCP::Server.new(
        name: SERVER_NAME,
        instructions: SERVER_INSTRUCTIONS,
        tools: tools,
        resources: resources
      )

      install_central_read_handler(server)
      server
    end

    def self.collect_tools
      return [] unless defined?(McpServer::Tools)
      McpServer::Tools.constants.map { |c| McpServer::Tools.const_get(c) }
        .select { |k| k.is_a?(Class) && k < MCP::Tool }
    end

    def self.collect_resources
      # Resources::*.all returns Array<MCP::Resource> (Plans 02-03 implement .all)
      # Plan 22-01: ContextCurrent added (context://current — Server-Kontext-Snapshot).
      collected = []
      [
        ("McpServer::Resources::WorkflowScenarios" if defined?(McpServer::Resources::WorkflowScenarios)),
        ("McpServer::Resources::WorkflowMeta" if defined?(McpServer::Resources::WorkflowMeta)),
        ("McpServer::Resources::ApiSurface" if defined?(McpServer::Resources::ApiSurface)),
        ("McpServer::Resources::ContextCurrent" if defined?(McpServer::Resources::ContextCurrent))
      ].compact.each do |const_name|
        klass = const_name.constantize
        collected.concat(klass.all) if klass.respond_to?(:all)
      end
      collected
    end

    # Single central dispatcher — routes resources/read requests to the right registry class
    # by URI scheme + path prefix. Per revision Blocker 2+3: ONE handler per server.
    #
    # Mime-Type-Variabilität (Plan 03-02 Task 2 — vorab in 03-01-RESEARCH §1.4 begründet):
    # Resource-Klassen-`.read`-Methoden dürfen einen Hash `{content:, mime_type:}` zurückgeben;
    # `normalize_resource_result` liefert Backwards-Kompatibilität für String-Returns
    # (alte Markdown-Resources). URI-Patterns + Routing-Verhalten ändern sich nicht.
    def self.install_central_read_handler(server)
      server.resources_read_handler do |params|
        uri = params[:uri].to_s
        case uri
        when %r{\Acc://workflow/scenarios/(?<slug>[\w-]+)\z}
          if defined?(McpServer::Resources::WorkflowScenarios)
            result = McpServer::Resources::WorkflowScenarios.read(slug: $~[:slug])
            content, mime_type = normalize_resource_result(result, default_mime: "text/markdown")
            [{uri: uri, mimeType: mime_type, text: content}]
          end
        when %r{\Acc://workflow/(?<key>roles|glossary)\z}
          if defined?(McpServer::Resources::WorkflowMeta)
            result = McpServer::Resources::WorkflowMeta.read(key: $~[:key])
            content, mime_type = normalize_resource_result(result, default_mime: "text/markdown")
            [{uri: uri, mimeType: mime_type, text: content}]
          end
        when %r{\Acc://api/(?<action>[\w-]+)\z}
          if defined?(McpServer::Resources::ApiSurface)
            result = McpServer::Resources::ApiSurface.read(action: $~[:action])
            content, mime_type = normalize_resource_result(result, default_mime: "text/markdown")
            [{uri: uri, mimeType: mime_type, text: content}]
          end
        when %r{\Acontext://current\z}
          # Plan 22-01: Server-Kontext-Snapshot (minimal-Form, ohne user-scope).
          # Für user-scope-Felder (sportwart_locations/disciplines) cc_whoami-Tool nutzen.
          if defined?(McpServer::Resources::ContextCurrent)
            result = McpServer::Resources::ContextCurrent.read(uri: uri)
            content, mime_type = normalize_resource_result(result, default_mime: "application/json")
            [{uri: uri, mimeType: mime_type, text: content}]
          end
        else
          # Per MCP spec: returning nil/empty causes the SDK to surface a ResourceNotFound error frame.
          nil
        end
      end
    end

    # Normalisiert Resource-Klassen-Returns auf [content, mime_type].
    # Backwards-kompatibel: ältere Markdown-Resources geben weiter Strings zurück.
    def self.normalize_resource_result(result, default_mime:)
      case result
      when Hash
        [result.fetch(:content, ""), result.fetch(:mime_type, default_mime)]
      when String
        [result, default_mime]
      else
        ["", default_mime]
      end
    end

    def self.eager_load_namespace!
      tools_dir = Rails.root.join("lib/mcp_server/tools")
      resources_dir = Rails.root.join("lib/mcp_server/resources")
      [tools_dir, resources_dir].each do |dir|
        Dir.glob(dir.join("*.rb")).sort.each { |f| require f }
      end
    end
  end
end
