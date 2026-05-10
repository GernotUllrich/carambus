# frozen_string_literal: true

# WorkflowScenarios — Exponiert ClubCloud-Workflow-Szenarien als MCP-Resources unter
# cc://workflow/scenarios/{slug} (D-06, D-07). Content ist DE (D-05).
#
# WICHTIG (Revision 2026-05-07 Blockers 2+3): Plan 01's `Server.install_central_read_handler`
# besitzt den zentralen Dispatcher. Diese Klasse exponiert nur `.all` (Resource-Liste) +
# `.read(slug:)` (Content-Lookup). KEIN eigener Handler-Aufruf hier — das würde mit
# Plan 03 in Wave 2 kollidieren.
#
# Sicherheit (T-40-02-01): Slug-Whitelist in SCENARIOS-Hash verhindert Path-Traversal.
# Plan 01's Dispatcher-Regex [\w-]+ blockt '/' und '..' bereits auf Dispatch-Ebene.

module McpServer
  module Resources
    class WorkflowScenarios
      # SCENARIOS-Hash — backwards-kompatibel:
      #   Slug => "title-string"          → Markdown-Default (mime "text/markdown", ext "de.md")
      #   Slug => { title:, mime_type:, file_ext: } → Override pro Spickzettel
      #
      # Plan 03-02: Phase-3-Walking-Skeleton fügt JSON-Spickzettel `anmeldung-aus-email` hinzu;
      # Plan 03-03 fügt `meldeliste-finalisieren` hinzu.
      # Existierende 3 Markdown-Slugs bleiben unverändert (Naming-Koexistenz-Decision).
      SCENARIOS = {
        "teilnehmerliste-finalisieren" => "Teilnehmerliste in ClubCloud finalisieren",
        "player-anlegen" => "Spieler in ClubCloud anlegen",
        "endrangliste-eintragen" => "Endrangliste in ClubCloud eintragen",
        "anmeldung-aus-email" => {
          title: "Anmeldung aus E-Mail",
          mime_type: "application/json",
          file_ext: "de.json"
        },
        "turnier-status-und-anmelden" => {
          title: "Turnier-Status prüfen und Spieler anmelden",
          mime_type: "application/json",
          file_ext: "de.json"
        },
        "meldeliste-finalisieren" => {
          title: "Meldeliste in ClubCloud finalisieren",
          mime_type: "application/json",
          file_ext: "de.json"
        }
      }.freeze

      DOCS_BASE = "docs/managers/clubcloud-scenarios"

      # Normalisiert SCENARIOS-Wert auf einheitlichen Hash mit title/mime_type/file_ext.
      # Backwards-kompatibel: String-Werte werden als Markdown-Default interpretiert.
      def self.scenario_meta(slug)
        raw = SCENARIOS[slug]
        case raw
        when String
          {title: raw, mime_type: "text/markdown", file_ext: "de.md"}
        when Hash
          {
            title: raw[:title],
            mime_type: raw.fetch(:mime_type, "text/markdown"),
            file_ext: raw.fetch(:file_ext, "de.md")
          }
        end
      end

      # Gibt Array<MCP::Resource> zurück. mime_type wird pro Slug aus scenario_meta geholt.
      def self.all
        SCENARIOS.keys.map do |slug|
          meta = scenario_meta(slug)
          MCP::Resource.new(
            uri: "cc://workflow/scenarios/#{slug}",
            name: "workflow-#{slug}",
            title: meta[:title],
            description: "ClubCloud-Workflow-Anleitung (DE) — Szenario: #{meta[:title]}",
            mime_type: meta[:mime_type]
          )
        end
      end

      # Wird vom zentralen Read-Handler-Dispatcher in server.rb aufgerufen.
      # Gibt Hash `{ content:, mime_type: }` zurück (Plan 03-02 Task 2: server.rb
      # normalisiert das via normalize_resource_result auf [content, mime_type]).
      # Wirft keine Exception — MCP-Client bekommt immer einen lesbaren String zurück.
      def self.read(slug:)
        unless SCENARIOS.key?(slug)
          return {content: "# Scenario nicht gefunden\n\nUnbekannter Slug: #{slug}", mime_type: "text/markdown"}
        end

        meta = scenario_meta(slug)
        path = Rails.root.join(DOCS_BASE, "#{slug}.#{meta[:file_ext]}")
        unless path.exist?
          return {content: "# Datei fehlt\n\nErwartet unter: #{path}", mime_type: "text/markdown"}
        end

        {content: path.read, mime_type: meta[:mime_type]}
      end
    end
  end
end
