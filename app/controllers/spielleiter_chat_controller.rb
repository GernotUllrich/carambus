# frozen_string_literal: true

class SpielleiterChatController < ApplicationController
  before_action :authenticate_user!

  SESSION_KEY = :spielleiter_chat_messages
  CONTEXT_KEY = :spielleiter_chat_context

  def show
    get_or_fetch_context  # Kontext cachen bevor erster POST
    @messages = session_messages
    @welcome_message = @messages.empty? ? build_welcome : nil
  end

  def create
    user_text = params[:message].to_s.strip
    return redirect_to spielleiter_chat_path if user_text.blank?

    context = get_or_fetch_context
    history = session_messages
    messages = context + history + [{role: "user", content: user_text}]
    ctx_len = context.length

    begin
      result = SpielleiterChatService.new(user: current_user).converse(messages: messages)
      session[SESSION_KEY] = result[:messages][ctx_len..].last(40)
    rescue => e
      Rails.logger.error("[SpielleiterChatController] #{e.class}: #{e.message}")
      flash[:alert] = "Fehler beim Verarbeiten der Anfrage. Bitte erneut versuchen."
    end

    redirect_to spielleiter_chat_path
  end

  def destroy
    session.delete(SESSION_KEY)
    session.delete(CONTEXT_KEY)
    redirect_to spielleiter_chat_path
  end

  private

  def get_or_fetch_context
    cached = session[CONTEXT_KEY]
    return cached.map { |m| deep_symbolize(m) } if cached

    context = fetch_whoami_context
    session[CONTEXT_KEY] = context
    context
  end

  def fetch_whoami_context
    server_ctx = {user_id: current_user.id, cc_region: Carambus.config.context.to_s.presence&.upcase}
    result = McpServer::Tools::CcWhoami.call(server_context: server_ctx)
    whoami_text = result.content.first[:text].to_s
    [
      {role: "user", content: "[Sportwart-Profil automatisch geladen] #{whoami_text}"},
      {role: "assistant", content: "Sportwart-Kontext geladen. Ich kenne deinen Scope und frage nicht nach club_cc_id."}
    ]
  rescue => e
    Rails.logger.warn("[SpielleiterChatController] cc_whoami: #{e.class} #{e.message}")
    []
  end

  def build_welcome
    name = current_user.first_name.presence || current_user.email.split("@").first
    data = whoami_data_from_context
    locations = Array(data["sportwart_locations"]).filter_map { |l| l["name"] }
    region = data.dig("region", "shortname")
    season = data["default_season"]

    parts = ["Willkommen zurück, #{name}!"]
    parts << "Du bist Sportwart für: #{locations.join(", ")}." if locations.any?
    parts << "(#{region}, Saison #{season})" if region && season
    parts << "Wie kann ich dir helfen?"
    parts.join(" ")
  end

  def whoami_data_from_context
    ctx = deep_symbolize(session[CONTEXT_KEY] || [])
    raw = ctx.first&.dig(:content).to_s
    JSON.parse(raw.sub(/\A\[Sportwart-Profil automatisch geladen\]\s*/, ""))
  rescue
    {}
  end

  def session_messages
    (session[SESSION_KEY] || []).map { |m| deep_symbolize(m) }
  end

  def deep_symbolize(obj)
    case obj
    when Hash then obj.transform_keys(&:to_sym).transform_values { |v| deep_symbolize(v) }
    when Array then obj.map { |v| deep_symbolize(v) }
    else obj
    end
  end
end
