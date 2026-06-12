class AiTranslationService
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

  def initialize(provider: :anthropic)
    @provider = provider

    raise "Unsupported provider #{@provider.inspect} — only :anthropic is supported" unless @provider == :anthropic

    @api_key = Rails.application.credentials.dig(:anthropic, :api_key)
    raise "Anthropic API key not found" unless @api_key
  end

  # Übersetzt Text mit AI und Billard-Kontext
  def translate(text:, source_lang:, target_lang:)
    return nil if text.blank?

    # Erstelle den Übersetzungs-Prompt
    prompt = build_translation_prompt(text, source_lang, target_lang)

    # Rufe die Claude-API auf
    response = call_claude_api(prompt)

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
    client = Anthropic::Client.new(api_key: @api_key)
    client.messages.create(
      model: "claude-haiku-4-5-20251001",
      max_tokens: 2048,
      messages: [{role: "user", content: prompt}]
    )
  rescue => e
    Rails.logger.error("Claude API Error: #{e.message}")
    nil
  end

  def extract_translation(response, provider)
    return nil unless response

    content = case provider
    when :anthropic
      response.content&.first&.text
    end

    content&.strip
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
