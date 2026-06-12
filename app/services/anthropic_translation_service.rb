# Service for translating text using Anthropic's Claude API (v0.8 — Anthropic SDK)
#
# This service provides AI-powered translation with understanding of
# carom billiard terminology. It uses the DeeplGlossaryService to include
# domain-specific terms in the translation context.
#
# Configuration:
#   Requires Carambus.anthropic_api_key (Rails credentials, kein ENV)
#
# Usage:
#   service = AnthropicTranslationService.new
#   translated = service.translate(
#     text: "De speelbal moet de eerste band raken",
#     source_lang: "nl",
#     target_lang: "de"
#   )
#
# Model: Claude Sonnet 4.6
class AnthropicTranslationService
  LANGUAGE_NAMES = {
    "de" => "German",
    "en" => "English",
    "nl" => "Dutch",
    "fr" => "French"
  }

  def initialize
    @client = Anthropic::Client.new(api_key: Carambus.anthropic_api_key)
  end

  def translate(text:, source_lang:, target_lang:)
    return nil if text.blank?

    source_name = LANGUAGE_NAMES[source_lang.downcase] || source_lang
    target_name = LANGUAGE_NAMES[target_lang.downcase] || target_lang

    system_prompt = <<~PROMPT
      You are a professional translator specializing in carom billiard terminology.
      Translate the following text from #{source_name} to #{target_name}.

      Important billiard-specific terms and their translations:
      #{get_glossary_terms(source_lang.downcase, target_lang.downcase)}

      CRITICAL: Preserve ALL line breaks exactly as they appear in the original text.
      Each line in the input should become a separate line in the output.

      Maintain the original formatting and tone.
      Only provide the translation, without any explanations or additional text.
    PROMPT

    response = @client.messages.create(
      model: "claude-sonnet-4-6",
      max_tokens: 4096,
      system: system_prompt,
      messages: [{role: "user", content: text}]
    )
    response.content.first&.text
  rescue => e
    Rails.logger.error("Anthropic Translation error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    nil
  end

  private

  def get_glossary_terms(source_lang, target_lang)
    glossary_service = DeeplGlossaryService.new
    glossary_data = glossary_service.get_glossary_data(source_lang, target_lang)

    return "" unless glossary_data

    terms = glossary_data.take(20).map do |source, target|
      "- #{source} → #{target}"
    end

    terms.join("\n")
  end
end
