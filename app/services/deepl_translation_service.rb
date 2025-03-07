require 'net/http'
require 'uri'
require 'json'

class DeeplTranslationService
  DEEPL_API_URL = "https://api-free.deepl.com/v2/translate"

  def self.translate(text, source_language = "DE", target_language = "EN")
    # Split content into front matter and body if present
    front_matter, content = split_front_matter(text)

    # Only translate the content, not the front matter
    translated_content = translate_content(content, source_language, target_language)

    # Recombine front matter with translated content
    [front_matter, translated_content]
  end

  private

  def self.split_front_matter(text)
    before, sep, after = text.rpartition(/---\n+/)
    [before+sep, after]
  end

  def self.translate_content(text, source_language = "DE", target_language = "EN")
    return nil if text.blank?

    api_key = ENV['DEEPL_API_KEY'].presence || Rails.application.credentials.fetch(:deepl_key)

    uri = URI.parse(DEEPL_API_URL)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "DeepL-Auth-Key #{api_key}"

    request.set_form_data({
      "text" => text,
      "source_lang" => source_language,
      "target_lang" => target_language,
      "preserve_formatting" => "1",
      "tag_handling" => "xml"
    })

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      result["translations"]&.first&.dig("text")
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
