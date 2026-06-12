# frozen_string_literal: true

# cc_smart_search — Phase 36-02. Read-only Chat-Tool: uebersetzt eine natuerlichsprachliche
# Suchanfrage in eine Carambus-Filter-Suche (Entity + Filter + klickbarer Pfad). Wrappt
# AiSearchService (seit 36-01 Claude). Registry-Stufe BASE_READ_TOOLS (alle authentifizierten User).
module McpServer
  module Tools
    class SmartSearch < BaseTool
      tool_name "cc_smart_search"
      description <<~DESC
        Wann nutzen? Wenn der Nutzer FREI ueber Carambus-Daten suchen will (Turniere, Spieler, Vereine, Ligen, Spielorte ...).
        Was tippt der User typisch? "Alle Dreiband-Turniere 2024", "Spieler Meyer aus Hamburg", "Vereine im NBV".
        Uebersetzt die Anfrage in die passende Carambus-Liste (Entity + Filter) inkl. klickbarem Link. Nur Lesen.
        NICHT fuer "meine" Daten — dafuer gibt es cc_my_tournaments / cc_my_results / cc_my_ranking.
        Optional `locale` ("de"/"en", Default "de").
      DESC
      input_schema(
        properties: {
          query: {type: "string", description: "Die Suchanfrage in natuerlicher Sprache."},
          locale: {type: "string", description: "Sprache: 'de' (Default) oder 'en'."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(query: nil, locale: "de", server_context: nil)
        return error("Bitte eine Suchanfrage angeben.") if query.blank?

        user = User.find_by(id: server_context&.dig(:user_id))
        result = AiSearchService.call(query: query, user: user, locale: locale.presence || "de")

        if result[:success]
          text(JSON.generate(
            entity: result[:entity],
            filters: result[:filters],
            path: result[:path],
            explanation: result[:explanation],
            confidence: result[:confidence]
          ))
        else
          error(result[:error].presence || "Suche nicht moeglich.")
        end
      rescue => e
        Rails.logger.warn "[SmartSearch.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end
    end
  end
end
