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
      # Per D-07 + RESEARCH §"Workflow Appendix Split (D-07 Empfehlung)":
      # 3 von 4 Scenarios shippen in Phase 40 (Upload-Failure-Recovery deferred).
      SCENARIOS = {
        "teilnehmerliste-finalisieren" => "Teilnehmerliste in ClubCloud finalisieren",
        "player-anlegen"               => "Spieler in ClubCloud anlegen",
        "endrangliste-eintragen"       => "Endrangliste in ClubCloud eintragen"
      }.freeze

      DOCS_BASE = "docs/managers/clubcloud-scenarios"

      # Gibt Array<MCP::Resource> mit genau 3 Einträgen zurück (D-06, D-07).
      def self.all
        SCENARIOS.map do |slug, title|
          MCP::Resource.new(
            uri: "cc://workflow/scenarios/#{slug}",
            name: "workflow-#{slug}",
            title: title,
            description: "ClubCloud-Workflow-Anleitung (DE) — Szenario: #{title}",
            mime_type: "text/markdown"
          )
        end
      end

      # Wird vom zentralen Read-Handler-Dispatcher in Plan 01 aufgerufen.
      # Gibt String (Markdown-Content) zurück, oder Not-Found-Body für unbekannte Slugs.
      # Wirft keine Exception — MCP-Client bekommt immer einen lesbaren String zurück.
      def self.read(slug:)
        return "# Scenario nicht gefunden\n\nUnbekannter Slug: #{slug}" unless SCENARIOS.key?(slug)

        path = Rails.root.join(DOCS_BASE, "#{slug}.de.md")
        return "# Datei fehlt\n\nErwartet unter: #{path}" unless path.exist?

        path.read
      end
    end
  end
end
