# frozen_string_literal: true

require "net/http"
require "openssl"
require "pdf-reader"
require "stringio"

# Stateless HTTP transport for UMB scrapers.
# SSL-Verifikation: VERIFY_NONE nur in development/test; VERIFY_PEER in production.
#
# Usage:
#   client = Umb::HttpClient.new
#   body = client.fetch_url("https://files.umb-carom.org/...")
class Umb::HttpClient
  TIMEOUT = 30

  # Returns the SSL verify mode for the current environment.
  # Public class method so UmbScraper/UmbScraperV2 can call it without
  # instantiating the full client.
  def self.ssl_verify_mode
    Rails.env.production? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
  end

  def fetch_url(url, follow_redirects: true, max_redirects: 5)
    uri = URI(url)
    redirects = 0

    loop do
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.verify_mode = self.class.ssl_verify_mode
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Carambus International Bot/1.0"
      response = http.request(request)

      case response
      when Net::HTTPSuccess
        return response.body
      when Net::HTTPRedirection
        return nil unless follow_redirects
        redirects += 1
        return nil if redirects >= max_redirects
        location = response["location"]
        uri = location.start_with?("http") ? URI(location) : URI.join(uri, location)
      else
        Rails.logger.warn "[Umb::HttpClient] HTTP #{response.code} for #{url}"
        return nil
      end
    end
  rescue StandardError => e
    Rails.logger.error "[Umb::HttpClient] Error fetching #{url}: #{e.message}"
    nil
  end

  # Lädt eine PDF-Datei von der angegebenen URL und gibt den extrahierten Text zurück.
  # Gibt nil zurück bei HTTP-Fehler, leerer Antwort oder ungültigem PDF-Inhalt.
  # T-26-02: StandardError abfangen — ungültige PDFs dürfen den Prozess nicht zum Absturz bringen.
  def fetch_pdf_text(url)
    raw = fetch_url(url)
    return nil if raw.blank?

    reader = PDF::Reader.new(StringIO.new(raw))
    reader.pages.map(&:text).join("\n")
  rescue StandardError => e
    Rails.logger.error "[Umb::HttpClient] PDF parsing error for #{url}: #{e.message}"
    nil
  end

  private

  def ssl_verify_mode
    self.class.ssl_verify_mode
  end
end
