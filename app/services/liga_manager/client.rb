# frozen_string_literal: true

require "net/http"
require "json"

module LigaManager
  # Read-only HTTP-Client für die öffentliche LigaManager-API (ligen.billard.center).
  #
  # Die API weist anonyme Clients mit HTTP 403 ab; nötig sind Browser-Header
  # (User-Agent/Referer/Origin) — siehe Phase-6-Research
  # (.paul/phases/06-ligamanager-api-recon/06-01-RESEARCH.md).
  class Client
    DEFAULT_BASE_URL = "https://ligen.billard.center/api"
    SITE_ORIGIN = "https://ligen.billard.center"
    DEFAULT_REFERER = "#{SITE_ORIGIN}/landesverband-thueringen".freeze
    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                 "(KHTML, like Gecko) Chrome/120 Safari/537.36"

    def initialize(base_url: DEFAULT_BASE_URL, referer: DEFAULT_REFERER)
      @base_url = base_url.chomp("/")
      @referer = referer
    end

    # GET auf einen API-Pfad; gibt geparste Ruby-Daten zurück. Der
    # {success,message,data}-Envelope wird zu `data` ausgepackt; nackte Arrays/Objekte
    # werden unverändert durchgereicht. Nicht-200 → RuntimeError.
    def get(path, params = {})
      unwrap(JSON.parse(request(path, params, accept: "application/json")))
    end

    # GET, das den rohen Body zurückgibt (HTML-Spielbericht in Plan 07-02). Kein JSON-Parse.
    def get_html(path, params = {})
      request(path, params, accept: "text/html")
    end

    private

    def unwrap(json)
      return json["data"] if json.is_a?(Hash) && json.key?("success") && json.key?("data")

      json
    end

    def request(path, params, accept:)
      uri = build_uri(path, params)
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = USER_AGENT
      req["Referer"] = @referer
      req["Origin"] = SITE_ORIGIN
      req["Accept"] = accept
      req["X-Requested-With"] = "XMLHttpRequest"

      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(req)
      end

      raise "LigaManager API GET #{uri} → HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)

      res.body
    end

    def build_uri(path, params)
      uri = URI.parse("#{@base_url}/#{path.sub(%r{\A/}, "")}")
      uri.query = encode_params(params) if params.any?
      uri
    end

    # Kodiert Params inkl. Array-Werten als wiederholte Keys (z.B. status[]=2&status[]=3).
    def encode_params(params)
      params.flat_map do |key, value|
        Array(value).map do |v|
          "#{URI.encode_www_form_component(key.to_s)}=#{URI.encode_www_form_component(v.to_s)}"
        end
      end.join("&")
    end
  end
end
