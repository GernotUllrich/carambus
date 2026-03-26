require 'net/http'
require 'uri'
require 'json'

class AiTranslationService
  ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
  
  # Billard-Kontext für bessere Übersetzungen
  BILLIARD_CONTEXT = <<~CONTEXT
    Du bist ein Experte für Carambolage-Billard (französisches Billard ohne Taschen).
    
    WICHTIGE BEGRIFFE:
    - Carambolage/Karambolage: Treffen beider Objektbälle mit dem Spielball
    - Spielball (cue ball): Der Ball, den der Spieler mit dem Queue stößt
    - Objektball (object ball): Die anderen beiden Bälle, die getroffen werden müssen
    - Bande (cushion/rail): Die Gummibegrenzung des Tisches
    - Dreiband (three-cushion): Der Spielball muss 3 Banden berühren
    - Diamant (diamond): Markierungen an den Banden
    - Position: Aufstellung der Bälle
    - Stoß (shot/stroke): Ein einzelner Spielzug
    - Serie (run): Mehrere erfolgreiche Stöße hintereinander
    
    WICHTIG:
    - Verwende die französisch-deutschen Fachbegriffe (nicht englisch-deutsche)
    - "Ball" bleibt "Ball" (nicht "Kugel")
    - Positionsnamen bleiben meistens im Original (z.B. "Amerika-Position", nicht "Amerikanische Position")
    - Sei präzise bei technischen Beschreibungen
  CONTEXT
  
  def initialize(provider: :openai)
    @provider = provider
    
    case @provider
    when :anthropic
      @api_key = Rails.application.credentials.dig(:anthropic_key)
      raise "Anthropic API key not found" unless @api_key
    when :openai
      @api_key = Rails.application.credentials.dig(:openai, :api_key)
      raise "OpenAI API key not found" unless @api_key
    end
  end
  
  # Übersetzt Text mit AI und Billard-Kontext
  def translate(text:, source_lang:, target_lang:)
    return nil if text.blank?
    
    # Erstelle den Übersetzungs-Prompt
    prompt = build_translation_prompt(text, source_lang, target_lang)
    
    # Rufe die richtige API auf
    response = case @provider
    when :anthropic
      call_claude_api(prompt)
    when :openai
      call_openai_api(prompt)
    end
    
    # Extrahiere die Übersetzung aus der Antwort
    extract_translation(response, @provider)
  rescue => e
    Rails.logger.error("AI Translation error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    nil
  end
  
  private
  
  def build_translation_prompt(text, source_lang, target_lang)
    source_name = language_name(source_lang)
    target_name = language_name(target_lang)
    
    <<~PROMPT
      #{BILLIARD_CONTEXT}
      
      Übersetze den folgenden Text von #{source_name} nach #{target_name}.
      
      Beachte dabei:
      1. Der Text handelt von Carambolage-Billard
      2. Verwende die korrekten Fachbegriffe
      3. Übersetze NUR den Text, keine Erklärungen
      4. Behalte die Formatierung bei (Absätze, Zeilenumbrüche)
      
      TEXT ZU ÜBERSETZEN:
      #{text}
      
      ÜBERSETZUNG:
    PROMPT
  end
  
  def call_claude_api(prompt)
    uri = URI.parse(ANTHROPIC_API_URL)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-api-key"] = @api_key
    request["anthropic-version"] = "2023-06-01"
    
    request.body = {
      model: "claude-3-sonnet-20240229",
      max_tokens: 2048,
      messages: [
        {
          role: "user",
          content: prompt
        }
      ]
    }.to_json
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.read_timeout = 30
      http.request(request)
    end
    
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error("Claude API Error: #{response.code} - #{response.body}")
      nil
    end
  end
  
  def call_openai_api(prompt)
    uri = URI.parse("https://api.openai.com/v1/chat/completions")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{@api_key}"
    
    request.body = {
      model: "gpt-4o-mini",
      messages: [
        {
          role: "user",
          content: prompt
        }
      ],
      max_tokens: 2048,
      temperature: 0.3
    }.to_json
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.read_timeout = 30
      http.request(request)
    end
    
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error("OpenAI API Error: #{response.code} - #{response.body}")
      nil
    end
  end
  
  def extract_translation(response, provider)
    return nil unless response
    
    case provider
    when :anthropic
      # Claude gibt die Antwort im "content" Array zurück
      content = response.dig("content", 0, "text")
    when :openai
      # OpenAI gibt die Antwort in "choices" zurück
      content = response.dig("choices", 0, "message", "content")
    end
    
    return nil unless content
    
    # Entferne eventuelle Markdown-Formatierung oder Erklärungen
    content.strip
  end
  
  def language_name(code)
    case code.to_s.upcase
    when "DE" then "Deutsch"
    when "EN" then "Englisch"
    when "FR" then "Französisch"
    when "NL" then "Niederländisch"
    else code
    end
  end
end
