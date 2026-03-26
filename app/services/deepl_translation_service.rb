require 'net/http'
require 'uri'
require 'json'
require 'cgi'

class DeeplTranslationService
  DEEPL_API_URL = "https://api.deepl.com/v2/translate"

  def self.translate(text, source_language = "DE", target_language = "EN")
    # Split content into front matter and body if present
    front_matter, content = split_front_matter(text)

    # Only translate the content, not the front matter
    translated_content = translate_content(content, source_language, target_language)

    # Recombine front matter with translated content
    [front_matter, translated_content]
  end
  
  # Instance method for direct translation without front matter handling
  def translate(text:, source_lang:, target_lang:)
    self.class.translate_content(text, source_lang, target_lang)
  end

  private

  def self.split_front_matter(text)
    before, sep, after = text.rpartition(/---\n+/)
    [before+sep, after]
  end

  def self.translate_content(text, source_language = "DE", target_language = "EN")
    return nil if text.blank?

    api_key = ENV['DEEPL_API_KEY'].presence || Rails.application.credentials.fetch(:deepl_key)
    # Remove :fx suffix for Pro API (Free API keys end with :fx, Pro keys don't)
    api_key = api_key.to_s.sub(/:fx$/, '')

    uri = URI.parse(DEEPL_API_URL)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "DeepL-Auth-Key #{api_key}"

    # Versuche, passendes Billard-Glossar zu verwenden
    glossary_id = nil
    supported_pairs = [
      ["EN", "DE"], 
      ["NL", "DE"], 
      ["NL", "EN"]
    ]
    
    if supported_pairs.include?([source_language.upcase, target_language.upcase])
      begin
        glossary_service = DeeplGlossaryService.new
        glossary_id = glossary_service.get_or_create_glossary_id(
          source_language.downcase, 
          target_language.downcase
        )
      rescue => e
        Rails.logger.warn("Could not load glossary, continuing without: #{e.message}")
      end
    end

    form_data = {
      "text" => text,
      "source_lang" => source_language,
      "target_lang" => target_language,
      "preserve_formatting" => "1",
      "tag_handling" => "html"
    }
    
    # Glossar nur hinzufügen, wenn vorhanden
    form_data["glossary_id"] = glossary_id if glossary_id
    
    request.set_form_data(form_data)

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      translated_text = result["translations"]&.first&.dig("text")
      # Decode HTML entities (DeepL returns &gt; instead of >, etc.)
      translated_text ? CGI.unescapeHTML(translated_text) : nil
    else
      Rails.logger.error("DeepL API Error: #{response.body}")
      nil
    end
  rescue => e
    Rails.logger.error("Translation error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    nil
  end

  def self.test_translation
    text = <<~MARKDOWN
      ---
      title: Überschrift
      summary: Eine Zusammenfassung
      ---

      # Einleitung

      Dies ist ein Test-Dokument mit YAML Front Matter.
    MARKDOWN

    result = translate(text)
    puts "\nOriginal:\n#{text}"
    puts "\nTranslation:\n#{result || 'Failed'}"
    result
  end
end
