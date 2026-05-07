# frozen_string_literal: true
# WorkflowMeta — Meta-Resources cc://workflow/roles + cc://workflow/glossary (D-07).
# Plan 01's zentraler Dispatcher besitzt den read_handler —
# diese Klasse stellt nur .all + .read(key:) bereit.
#
# Sicherheit (T-40-02-01): META-Hash ist Whitelist; unbekannte Keys werden mit Not-Found-Body
# beantwortet, niemals als Dateipfad interpretiert.

module McpServer
  module Resources
    class WorkflowMeta
      META = {
        "roles"    => { title: "ClubCloud-Rollenmodell", file: "cc-roles.de.md" },
        "glossary" => { title: "ClubCloud-Glossar",      file: "cc-glossary.de.md" }
      }.freeze

      DOCS_BASE = "docs/managers/clubcloud-scenarios"

      # Gibt Array<MCP::Resource> mit genau 2 Einträgen zurück (D-06, D-07).
      def self.all
        META.map do |key, meta|
          MCP::Resource.new(
            uri: "cc://workflow/#{key}",
            name: "workflow-#{key}",
            title: meta[:title],
            description: "ClubCloud-Meta (DE): #{meta[:title]}",
            mime_type: "text/markdown"
          )
        end
      end

      # Wird vom zentralen Read-Handler-Dispatcher in Plan 01 aufgerufen.
      # Gibt String (Markdown-Content) zurück, oder Not-Found-Body für unbekannte Keys.
      def self.read(key:)
        meta = META[key]
        return "# Unknown meta key\n\nKey: #{key}" unless meta

        path = Rails.root.join(DOCS_BASE, meta[:file])
        return "# Datei fehlt\n\nErwartet unter: #{path}" unless path.exist?

        path.read
      end
    end
  end
end
