# frozen_string_literal: true

# cc_doc_search — Phase 36-02. Read-only Chat-Tool: durchsucht die Carambus-Dokumentation
# (MkDocs) und liefert eine KI-Antwort mit Quellen-Links. Wrappt AiDocsService (seit 36-01 Claude).
# Self ueber server_context[:user_id]; Registry-Stufe BASE_READ_TOOLS (alle authentifizierten User).
module McpServer
  module Tools
    class DocSearch < BaseTool
      tool_name "cc_doc_search"
      description <<~DESC
        Wann nutzen? Wenn der Nutzer eine HILFE-/BEDIENUNGS-/REGEL-Frage zu Carambus stellt, die in der Dokumentation steht.
        Was tippt der User typisch? "Wie lege ich ein Turnier an?", "Wie funktioniert die Akkreditierung?", "Was bedeutet ...?".
        Durchsucht die Carambus-Dokumentation und antwortet mit Quellen-Links. Nur Lesen, keine Aenderung.
        Optional `locale` ("de"/"en", Default "de").
      DESC
      input_schema(
        properties: {
          query: {type: "string", description: "Die Frage des Nutzers in natuerlicher Sprache."},
          locale: {type: "string", description: "Sprache der Antwort: 'de' (Default) oder 'en'."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(query: nil, locale: "de", server_context: nil)
        return error("Bitte eine Frage angeben.") if query.blank?

        user = User.find_by(id: server_context&.dig(:user_id))
        result = AiDocsService.call(query: query, user: user, locale: locale.presence || "de")

        if result[:success]
          text(JSON.generate(
            answer: result[:answer],
            docs_links: result[:docs_links],
            confidence: result[:confidence]
          ))
        else
          error(result[:error].presence || "Dokumentations-Suche nicht moeglich.")
        end
      rescue => e
        Rails.logger.warn "[DocSearch.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end
    end
  end
end
