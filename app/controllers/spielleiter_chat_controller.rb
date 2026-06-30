# frozen_string_literal: true

class SpielleiterChatController < ApplicationController
  before_action :authenticate_user!
  before_action :require_local_server!

  SESSION_KEY = :spielleiter_chat_messages
  CONTEXT_KEY = :spielleiter_chat_context
  MAX_HISTORY = 40

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
      session[SESSION_KEY] = trim_history(result[:messages][ctx_len..])
      record_ai_usage(result[:usage_by_model])
    rescue => e
      Rails.logger.error("[SpielleiterChatController] #{e.class}: #{e.message}")
      flash[:alert] = "Fehler beim Verarbeiten der Anfrage. Bitte erneut versuchen."
    end

    redirect_to spielleiter_chat_path
  end

  def print
    @messages = session_messages
    render layout: false
  end

  def destroy
    session.delete(SESSION_KEY)
    session.delete(CONTEXT_KEY)
    redirect_to spielleiter_chat_path
  end

  private

  # 49-01: AI-Token-Verbrauch des Turns je Modell persistieren (AiUsageEvent). In EIGENEM rescue —
  # Telemetrie darf den Chat NIE brechen (ein Persist-Fehler wird nur geloggt).
  def record_ai_usage(usage_by_model)
    return if usage_by_model.blank?
    AiUsageEvent.record_turn(usage_by_model: usage_by_model, user: current_user,
      scenario: Carambus.config.context)
  rescue => e
    Rails.logger.error("[SpielleiterChatController] AiUsageEvent persist: #{e.class}: #{e.message}")
  end

  # Der Assistent/Chat steht NUR auf Local-Servern zur Verfügung. Auf der zentralen
  # Authority (api.carambus.de) ist er NICHT freigegeben: der Server ist nicht für die
  # Allgemeinheit bestimmt, CC-Schreibaktionen liefen dort fehl-attribuiert (Phase 39),
  # und persönliche Anfragen (Player-Verknüpfung) funktionieren dort ohnehin nicht.
  def require_local_server!
    return if local_server?
    redirect_to root_path, alert: "Der Carambus-Assistent steht auf diesem Server nicht zur Verfügung."
  end

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
      {role: "user", content: "[Profil automatisch geladen] #{whoami_text}"},
      {role: "assistant", content: "Profil geladen. Ich kenne deinen Scope (Rolle, Region, ggf. Wirkbereich) und frage nicht nach internen IDs."}
    ]
  rescue => e
    Rails.logger.warn("[SpielleiterChatController] cc_whoami: #{e.class} #{e.message}")
    []
  end

  def build_welcome
    # D-35/D-38: bevorzugt den Namen des verknuepften Players (current_user.player), sonst User-Name.
    name = current_user.player&.firstname.presence ||
      current_user.first_name.presence ||
      current_user.email.split("@").first
    data = whoami_data_from_context
    locations = Array(data["sportwart_locations"]).filter_map { |l| l["name"] }
    personas = Array(data["personas"])
    region = data.dig("region", "shortname")
    season = data["default_season"]

    parts = ["Willkommen zurück, #{name}!"]
    # D-38: Persona-Zuschreibung ist EXPLIZIT (persona_grants), NICHT aus Join-Präsenz abgeleitet.
    # Ein club_admin mit sportwart_locations-Joins (aber ohne sportwart-Grant) ist KEIN Sportwart.
    if personas.include?("landessportwart")
      parts << "Du bist Landessportwart."
    elsif personas.include?("sportwart")
      parts << (locations.any? ? "Du bist Sportwart für: #{locations.join(", ")}." : "Du bist als Sportwart eingetragen.")
    elsif personas.include?("turnierleiter")
      parts << "Du bist als Turnierleiter eingetragen."
    elsif personas.include?("club_admin")
      parts << "Du bist Vereins-Administrator."
    end
    parts << "(#{region}, Saison #{season})" if region && season
    parts << "Wie kann ich dir helfen?"
    parts.join(" ")
  end

  def whoami_data_from_context
    ctx = deep_symbolize(session[CONTEXT_KEY] || [])
    raw = ctx.first&.dig(:content).to_s
    JSON.parse(raw.sub(/\A\[(?:Sportwart-)?Profil automatisch geladen\]\s*/, ""))
  rescue
    {}
  end

  def session_messages
    (session[SESSION_KEY] || []).map { |m| deep_symbolize(m) }
  end

  # History-Kürzung an TURN-GRENZEN statt per Nachrichten-Zahl. Ein stumpfes `last(N)` kann ein
  # tool_use(assistant)/tool_result(user)-Paar zerschneiden — bleibt am Rand ein verwaistes
  # tool_result, lehnt die Anthropic-API JEDEN Folge-Request mit 400 ab ("tool_result without
  # corresponding tool_use") und der Chat ist tot ("nichts geht mehr"). Daher nach `last(N)` so
  # lange vom Anfang kürzen, bis die History an einem echten Turn-Anfang (User-TEXT) beginnt.
  def trim_history(messages)
    trimmed = Array(messages).last(MAX_HISTORY)
    trimmed.shift while trimmed.any? && !turn_start?(trimmed.first)
    trimmed
  end

  # Turn-Anfang = User-Nachricht mit reinem Text (kein tool_result-Array, kein assistant-Block).
  def turn_start?(msg)
    msg[:role].to_s == "user" && msg[:content].is_a?(String)
  end

  def deep_symbolize(obj)
    case obj
    when Hash then obj.transform_keys(&:to_sym).transform_values { |v| deep_symbolize(v) }
    when Array then obj.map { |v| deep_symbolize(v) }
    else obj
    end
  end
end
