# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"

class RegionDump
  # Holt den Regionsdump beim Verein (Plan 18-03): erst latest.json, dann genau die dort genannte Datei
  # (nicht latest.sql.gz — der Link kann zwischen beiden Abrufen wechseln). Groesse und sha256 werden gegen
  # das Manifest geprueft, bevor die Datei ihren endgueltigen Namen bekommt.
  # Basic Auth ueber Net::HTTP: das Passwort erscheint in keiner Prozessliste und in keiner Ausgabe.
  class Fetch
    class Error < StandardError; end

    HTTP_ERRORS = {
      "401" => "Zugangsdaten falsch oder entzogen — beim Betreiber nachfragen",
      "403" => "für diese Region ist kein Zugang eingerichtet (oder der Bot-Block der Authority weist ab)",
      "404" => "für diese Region liegt kein Dump vor"
    }.freeze

    def initialize(url:, region:, login:, password:, dir:, log: $stdout)
      @url = url.to_s.chomp("/")
      @region = region.to_s.upcase
      @login = login
      @password = password
      @dir = dir
      @log = log
    end

    # Liefert [pfad, manifest].
    def run
      FileUtils.mkdir_p(@dir, mode: 0o700)
      manifest = RegionDump.validate_manifest!(JSON.parse(get("latest.json")), region: @region)
      path = File.join(@dir, manifest["file"])
      if File.exist?(path) && intact?(path, manifest)
        say "   ✅ Dump liegt schon vor: #{manifest["file"]}"
      else
        download(manifest, path)
      end
      RegionDump.expired(Dir.children(@dir)).each { |f| FileUtils.rm_f(File.join(@dir, f)) }
      [path, manifest]
    rescue JSON::ParserError => e
      raise Error, "latest.json ist kein JSON: #{e.message}"
    rescue ArgumentError => e
      raise Error, e.message
    end

    private

    def say(msg)
      @log&.puts(msg)
    end

    def uri(file)
      URI("#{@url}/region_dumps/#{@region}/#{file}")
    end

    def request(file, &block)
      target = uri(file)
      Net::HTTP.start(target.host, target.port, use_ssl: target.scheme == "https", open_timeout: 15, read_timeout: 120) do |http|
        req = Net::HTTP::Get.new(target)
        req.basic_auth(@login, @password)
        http.request(req) do |res|
          unless res.is_a?(Net::HTTPSuccess)
            raise Error, "#{target} → HTTP #{res.code}: #{HTTP_ERRORS.fetch(res.code, res.message)}"
          end

          block.call(res)
        end
      end
    rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
      raise Error, "#{target} nicht erreichbar: #{e.class}: #{e.message}"
    end

    def get(file)
      body = +""
      request(file) { |res| body = res.body.to_s }
      body
    end

    def download(manifest, path)
      part = "#{path}.part"
      say "   📥 Lade #{manifest["file"]} (#{(manifest["size"] / 1024.0 / 1024).round(1)} MB) von #{@url}"
      File.open(part, "wb", 0o600) do |f|
        request(manifest["file"]) { |res| res.read_body { |chunk| f.write(chunk) } }
      end
      raise Error, "Download unvollständig oder verändert: Größe/sha256 passen nicht zum Manifest" unless intact?(part, manifest)

      File.rename(part, path)
      say "   ✅ Dump geprüft (Größe, sha256): #{manifest["file"]}"
    ensure
      FileUtils.rm_f(part) if part
    end

    def intact?(file, manifest)
      File.size(file) == manifest["size"] && Digest::SHA256.file(file).hexdigest == manifest["sha256"]
    end
  end
end
