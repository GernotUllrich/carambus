require 'net/http'
require 'uri'
require 'json'

# Service for translating text using Anthropic's Claude API
#
# This service provides AI-powered translation with understanding of
# carom billiard terminology. It uses the DeeplGlossaryService to include
# domain-specific terms in the translation context.
#
# Configuration:
#   Requires anthropic.api_key in Rails credentials
#
# Usage:
#   service = AnthropicTranslationService.new
#   translated = service.translate(
#     text: "De speelbal moet de eerste band raken",
#     source_lang: "nl",
#     target_lang: "de"
#   )
#
# Model: Claude Sonnet 4.6 (March 2026)
# Cost: ~$3 per million input tokens
class AnthropicTranslationService
  ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
  
  LANGUAGE_NAMES = {
    'de' => 'German',
    'en' => 'English',
    'nl' => 'Dutch',
    'fr' => 'French'
  }
  
  def initialize
    @api_key = Rails.application.credentials.dig(:anthropic, :api_key)&.to_s&.strip
    Rails.logger.info("Anthropic API Key loaded: #{@api_key.present? ? "#{@api_key[0..15]}...#{@api_key[-10..]} (length: #{@api_key.length})" : 'MISSING'}")
  end
  
  def translate(text:, source_lang:, target_lang:)
    return nil if text.blank?
    return nil unless @api_key.present?
    
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
    
    uri = URI.parse(ANTHROPIC_API_URL)
    request = Net::HTTP::Post.new(uri)
    request["x-api-key"] = @api_key
    request["anthropic-version"] = "2023-06-01"
    request["Content-Type"] = "application/json"
    
    request.body = {
      model: "claude-sonnet-4-6",
      max_tokens: 4096,
      system: system_prompt,
      messages: [
        {
          role: "user",
          content: text
        }
      ]
    }.to_json
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
    
    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      result.dig("content", 0, "text")
    else
      Rails.logger.error("Anthropic API Error: #{response.body}")
      nil
    end
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
