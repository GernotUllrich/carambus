# frozen_string_literal: true

# SpielleiterChatService — Anthropic Tool-Use Agentic Loop für Sportwart-Web-Chat (Phase 28).
# Hält eine Konversation mit 9 cc_*-Tools als Anthropic Tool-Definitionen und dispatcht
# tool_use-Blöcke an die entsprechenden McpServer::Tools-Klassen.
#
# Usage:
#   svc = SpielleiterChatService.new(user: current_user)
#   result = svc.converse(messages: [{role: "user", content: "Offene Turniere?"}])
#   result[:response]   # => "Hier sind die aktuell offenen Turniere: ..."
#   result[:messages]   # => vollständige Konversations-History für nächsten Aufruf
class SpielleiterChatService
  MAX_TOOL_ITERATIONS = 10

  TOOL_CLASSES = {
    "cc_whoami" => McpServer::Tools::CcWhoami,
    "cc_list_open_tournaments" => McpServer::Tools::ListOpenTournaments,
    "cc_lookup_meldeliste_for_tournament" => McpServer::Tools::LookupMeldelisteForTournament,
    "cc_lookup_teilnehmerliste" => McpServer::Tools::LookupTeilnehmerliste,
    "cc_list_players_by_club_and_discipline" => McpServer::Tools::ListPlayersByClubAndDiscipline,
    "cc_search_player" => McpServer::Tools::SearchPlayer,
    "cc_check_player_discipline_experience" => McpServer::Tools::CheckPlayerDisciplineExperience,
    "cc_register_for_tournament" => McpServer::Tools::RegisterForTournament,
    "cc_unregister_for_tournament" => McpServer::Tools::UnregisterForTournament,
    "cc_assign_player_to_teilnehmerliste" => McpServer::Tools::AssignPlayerToTeilnehmerliste,
    "cc_remove_from_teilnehmerliste" => McpServer::Tools::RemoveFromTeilnehmerliste,
    "cc_update_tournament_deadline" => McpServer::Tools::UpdateTournamentDeadline
  }.freeze

  def initialize(user:)
    @user = user
    @client = Anthropic::Client.new(api_key: Rails.application.credentials.dig(:anthropic, :api_key))
    @server_context = {
      user_id: user.id,
      cc_region: Carambus.config.context.to_s.presence&.upcase
    }
  end

  def converse(messages:)
    loop_messages = messages.dup
    iterations = 0

    loop do
      iterations += 1
      break if iterations > MAX_TOOL_ITERATIONS

      response = @client.messages.create(
        model: "claude-haiku-4-5-20251001",
        max_tokens: 4096,
        system: system_prompt,
        tools: tool_definitions,
        messages: loop_messages
      )

      # Convert SDK blocks to plain hashes for message history (SDK objects are not re-serializable).
      assistant_content = response.content.map { |b| serialize_content_block(b) }
      loop_messages << {role: "assistant", content: assistant_content}

      break if response.stop_reason.to_s != "tool_use"

      # Dispatch all tool_use blocks and collect tool_results.
      tool_results = assistant_content
        .select { |b| b[:type] == "tool_use" }
        .map { |b| dispatch_tool(name: b[:name], id: b[:id], input: b[:input]) }

      loop_messages << {role: "user", content: tool_results}
    end

    final_text = extract_final_text(loop_messages)
    {response: final_text, messages: loop_messages}
  end

  def tool_definitions
    TOOL_CLASSES.map do |name, klass|
      schema = klass.input_schema.to_h.compact
      schema = schema.merge(type: "object") unless schema[:type]
      {
        name: name,
        description: klass.description.to_s[0, 1024],
        input_schema: schema
      }
    end
  end

  private

  def dispatch_tool(name:, id:, input:)
    tool_class = TOOL_CLASSES[name]
    result_text = if tool_class
      begin
        kwargs = input.transform_keys(&:to_sym)
        tool_response = tool_class.call(**kwargs, server_context: @server_context)
        tool_response.content.first[:text].to_s
      rescue => e
        Rails.logger.error("[SpielleiterChatService] dispatch #{name}: #{e.class} #{e.message}")
        "Fehler bei #{name}: #{e.message}"
      end
    else
      "Unbekanntes Tool: #{name}"
    end

    {type: "tool_result", tool_use_id: id, content: result_text}
  end

  def serialize_content_block(block)
    case block.type.to_s
    when "tool_use"
      {type: "tool_use", id: block.id, name: block.name, input: block.input}
    else
      {type: "text", text: block.respond_to?(:text) ? block.text.to_s : ""}
    end
  end

  def extract_final_text(messages)
    last_assistant = messages.reverse.find { |m| m[:role] == "assistant" }
    Array(last_assistant&.dig(:content))
      .select { |b| b[:type] == "text" }
      .map { |b| b[:text] }
      .join
  end

  def system_prompt
    "Du bist ein Assistent für NBV-Sportwarte. " \
      "Du hilfst bei ClubCloud-Admin-Aufgaben: Turnierverwaltung, Melde- und Teilnehmerlisten. " \
      "Nutze die verfügbaren Tools für alle CC-Operationen. " \
      "Antworte auf Deutsch, kurz und sachlich. " \
      "Sei entscheidungsfreudig: Wenn eine Anfrage eindeutig ist, handle direkt — " \
      "zeige kein Menü mit Optionen, stelle keine Rückfragen wenn der Kontext klar ist. " \
      "Beispiel: 'zeige die Meldeliste des Cadre-Turniers' → Tool aufrufen, Ergebnis zeigen. " \
      "Wenn du eine Turnierliste anzeigst, stelle KEINE Nachfrage wie " \
      "'Welches Turnier möchtest du bearbeiten?' — " \
      "der Sportwart wählt direkt aus der Liste. " \
      "Für cc_list_open_tournaments: der discipline-Parameter filtert korrekt nach Branch " \
      "('Karambol' → findet auch Cadre 35/2, Dreiband groß etc.) oder konkreter Disziplin. " \
      "Wenn nach Meldungen oder der Meldeliste gefragt wird: rufe cc_lookup_meldeliste_for_tournament " \
      "und cc_lookup_teilnehmerliste separat auf und zeige beide Listen getrennt — " \
      "erst alle gemeldeten Spieler (Meldeliste), dann die akkreditierten (Teilnehmerliste). " \
      "Disziplin-Hierarchie: 'Karambol' (Disziplin 50) umfasst ALLE Karambol-Unterdisziplinen — " \
      "Cadre 35/1, Cadre 35/2, Cadre 47/1, Cadre 47/2, Cadre 71/2, Dreiband, Einband, Freie, Bricole. " \
      "Wenn sportwart_disciplines 'Karambol' enthält, hat der Sportwart Zugriff auf alle diese Unterdisziplinen. " \
      "Lehne KEINE Anfrage wegen Disziplin-Scope ab, bevor du das Tool aufgerufen hast — " \
      "der Server prüft die Berechtigung selbst. " \
      "Für cc_lookup_meldeliste_for_tournament gilt: nur tournament_cc_id ist Pflicht — " \
      "branch_cc_id, fed_cc_id, season und club_cc_id werden vom Server automatisch aufgelöst. " \
      "Entnimm branch_cc_id aus sportwart_disciplines[x].branch_cc_id im cc_whoami-Kontext. " \
      "Frage den Sportwart NIEMALS nach branch_cc_id, Saison, fed_cc_id oder ähnlichen " \
      "Server-internen Parametern — diese ergeben sich vollständig aus dem Kontext. " \
      "Erwähne Server-interne Parameter-Namen (branch_cc_id, fed_cc_id, tournament_cc_id, " \
      "meldeliste_cc_id, player_cc_id, discipline_id, location_id) NIEMALS in Antworten — " \
      "weder als Frage noch in Fehlermeldungen noch in Erklärungen. " \
      "Wenn ein Tool-Call fehlschlägt, beschreibe das Problem in Alltagssprache ohne interne Namen. " \
      "Für CC-Schreiboperationen (cc_assign_player_to_teilnehmerliste, " \
      "cc_remove_from_teilnehmerliste, cc_register_for_tournament, " \
      "cc_unregister_for_tournament, cc_update_tournament_deadline): " \
      "Setze armed: true sobald der Sportwart die Aktion bestätigt hat. " \
      "armed: false (Default) ist nur ein Probelauf — ohne armed: true wird " \
      "NICHTS in ClubCloud geändert. " \
      "Zeige dem Sportwart KEINE internen IDs (cc_id, branch_id, discipline_id, tournament_cc_id, " \
      "meldeliste_cc_id, player_cc_id o.ä.) — nur Namen, Bezeichnungen und Ergebnisse. " \
      "Verwende keine IT-Fachbegriffe wie Flapping, Eventual Consistency, Caching, Race-Condition, " \
      "Buffer, Stale Read, Token oder PUT-Replace in Erklärungen an den Sportwart."
  end
end
