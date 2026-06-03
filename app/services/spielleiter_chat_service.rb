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
    "cc_search_player" => McpServer::Tools::SearchPlayer,
    "cc_register_for_tournament" => McpServer::Tools::RegisterForTournament,
    "cc_unregister_for_tournament" => McpServer::Tools::UnregisterForTournament,
    "cc_assign_player_to_teilnehmerliste" => McpServer::Tools::AssignPlayerToTeilnehmerliste,
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

      break if response.stop_reason != "tool_use"

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
      "Antworte auf Deutsch, kurz und sachlich."
  end
end
