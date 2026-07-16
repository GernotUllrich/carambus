# frozen_string_literal: true

require "net/http"
require "nokogiri"

module NuLiga
  # Read-only HTTP-Client für das öffentliche NuLiga-Portal des BBV (bbv-billard.liga.nu).
  #
  # NuLiga ist ein WebObjects-System und liefert ausschließlich HTML (ISO-8859-1). Der Client
  # kapselt: URL-Bau (wa/<action>?<params>), Encoding-Dekodierung, Bereinigung der WebObjects-
  # Artefakte (//--, uLigaStatsRefUrl-meta) und optionales Nokogiri-Parsing.
  # Endpunkt-Katalog: .paul/phases/13-nuliga-recon/13-01-RESEARCH.md.
  class Client
    DEFAULT_BASE_URL = "https://bbv-billard.liga.nu"
    WA_PATH = "/cgi-bin/WebObjects/nuLigaBILLARDDE.woa/wa"
    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                 "(KHTML, like Gecko) Chrome/120 Safari/537.36"
    # Backoff für transiente NuLiga-Redirects (WebObjects antwortet bei Request-Bursts mit 302 Rate-Limit/
    # Session-Redirect; dieselbe URL liefert nach kurzer Pause wieder 200). Nur 3xx wird retried, 4xx/5xx nicht.
    RETRY_DELAYS = [2, 5, 10].freeze

    def initialize(base_url: DEFAULT_BASE_URL)
      @base_url = base_url.chomp("/")
    end

    # GET auf eine wa/-Aktion; gibt den bereinigten UTF-8-HTML-String zurück. Nicht-2xx → RuntimeError.
    def get_html(action, params = {})
      clean(decode(request(action, params)))
    end

    # Wie #get_html, aber als Nokogiri-Fragment (zum Parsen im Scraper).
    def get_doc(action, params = {})
      Nokogiri::HTML.fragment(get_html(action, params))
    end

    # Baut den NuLiga-championship-String robust: "BBV Pool 25/26" aus federation/branch/season_name.
    # season_name "2025/2026" → "25/26" (letzte zwei Stellen je Jahr). KEINE %20-Zufallsmechanik.
    def self.championship(federation:, branch:, season_name:)
      short = season_name.to_s.split("/").map { |y| y.strip[-2..] || y.strip }.join("/")
      "#{federation} #{branch} #{short}"
    end

    private

    def request(action, params)
      uri = build_uri(action, params)
      attempt = 0
      loop do
        res = perform_get(uri)
        return res.body if res.is_a?(Net::HTTPSuccess)
        # Nur transiente 3xx (Rate-Limit/Session-Redirect) werden mit Backoff wiederholt — 4xx/5xx sofort fatal.
        unless res.is_a?(Net::HTTPRedirection) && attempt < RETRY_DELAYS.length
          raise "NuLiga GET #{uri} → HTTP #{res.code}"
        end
        sleep(RETRY_DELAYS[attempt]) unless defined?(Rails) && Rails.env.test?
        attempt += 1
      end
    end

    def perform_get(uri)
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = USER_AGENT
      req["Accept"] = "text/html"
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(req)
      end
    end

    def build_uri(action, params)
      uri = URI.parse("#{@base_url}#{WA_PATH}/#{action.sub(%r{\A/}, "")}")
      uri.query = encode_params(params) if params.any?
      uri
    end

    # encode_www_form: Leerzeichen → "+", "/" → "%2F" (genau das NuLiga-championship-Format).
    def encode_params(params)
      URI.encode_www_form(params)
    end

    # Dekodiert den Roh-Body zu UTF-8. Das moderne BBV-NuLiga liefert UTF-8 (meta charset=utf-8);
    # Fallback auf ISO-8859-1 für etwaige Legacy-Seiten.
    def decode(body)
      utf8 = body.dup.force_encoding("UTF-8")
      return utf8 if utf8.valid_encoding?

      body.dup.force_encoding("ISO-8859-1").encode("UTF-8")
    end

    # Entfernt WebObjects-Artefakte, die Nokogiri sonst stören (wie League::BbvScraper.fetch_league_doc).
    def clean(html)
      html
        .gsub("//--", "--")
        .gsub('id="banner-groupPage-content"', "")
        .gsub(%r{<meta name="uLigaStatsRefUrl"\s*/>}, "")
        .gsub("</meta>", "")
    end
  end
end
