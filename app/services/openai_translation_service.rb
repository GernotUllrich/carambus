require 'net/http'
require 'uri'
require 'json'

class OpenaiTranslationService
  OPENAI_API_URL = "https://api.openai.com/v1/chat/completions"
  
  LANGUAGE_NAMES = {
    'de' => 'German',
    'en' => 'English',
    'nl' => 'Dutch',
    'fr' => 'French'
  }
  
  def initialize
    @api_key = Rails.application.credentials.dig(:openai, :api_key)&.to_s&.strip
    Rails.logger.info("OpenAI API Key loaded: #{@api_key.present? ? "#{@api_key[0..20]}...#{@api_key[-10..]} (length: #{@api_key.length})" : 'MISSING'}")
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
      
      Maintain the original formatting and tone.
      Only provide the translation, without any explanations or additional text.
    PROMPT
    
    uri = URI.parse(OPENAI_API_URL)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    
    request.body = {
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content: system_prompt
        },
        {
          role: "user",
          content: text
        }
      ],
      temperature: 0.3
    }.to_json
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
    
    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      result.dig("choices", 0, "message", "content")
    else
      Rails.logger.error("OpenAI API Error: #{response.body}")
      nil
    end
  rescue => e
    Rails.logger.error("OpenAI Translation error: #{e.message}")
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
