# frozen_string_literal: true

# Throwaway probe script — NOT part of app/ — do not commit to production code
# Run with: bundle exec ruby tmp/probe_umbevents.rb
#
# Purpose: Determine whether umbevents.umb-carom.org/Reports/ endpoints return JSON
# when requested with various Accept headers and query parameters.
# Results feed into Phase 24 findings document (24-FINDINGS.md).

require "net/http"
require "json"
require "uri"
require "openssl"
require "fileutils"

SAMPLES_DIR = File.expand_path("../samples/umbevents", __FILE__)
FileUtils.mkdir_p(SAMPLES_DIR)

# Copy of UmbScraperV2#fetch_url pattern (lines 57-91) adapted for probe use.
# Handles redirects, SSL, and returns the full response object for header inspection.
def fetch_url(url, headers = {})
  uri = URI(url)
  redirects = 0
  max_redirects = 5

  loop do
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 15

    path = uri.path.empty? ? "/" : uri.path
    path += "?#{uri.query}" if uri.query
    request = Net::HTTP::Get.new(path, headers)

    response = http.request(request)

    case response
    when Net::HTTPSuccess
      return response
    when Net::HTTPRedirection
      redirects += 1
      return nil if redirects >= max_redirects

      location = response["location"]
      uri = location.start_with?("http") ? URI(location) : URI.join(uri, location)
    else
      # Return non-success responses for inspection (they may contain useful error messages)
      return response
    end
  end
rescue => e
  puts "  [ERROR] #{e.class}: #{e.message}"
  nil
end

def probe(label, url, headers = {})
  puts "\n--- #{label} ---"
  puts "URL:     #{url}"
  puts "Headers: #{headers.empty? ? "(default)" : headers.inspect}"

  response = fetch_url(url, headers)

  if response.nil?
    puts "Result:  nil (error or redirect loop)"
    return
  end

  content_type = response["content-type"] || "(none)"
  puts "Status:  #{response.code}"
  puts "Content-Type: #{content_type}"

  body = response.body || ""
  puts "Body (first 300 chars):"
  puts body[0..299]

  # Save full response body if JSON
  if content_type.include?("json")
    filename = "#{label.gsub(/[^a-z0-9_]/i, "_")}.json"
    filepath = File.join(SAMPLES_DIR, filename)
    File.write(filepath, body)
    puts "\n[JSON FOUND] Saved full response to #{filepath}"
  end
end

# Header combinations to test per endpoint
HEADER_VARIANTS = [
  {},
  { "Accept" => "application/json" },
  { "Accept" => "application/json", "X-Requested-With" => "XMLHttpRequest" },
  {
    "Accept" => "application/json, text/javascript, */*; q=0.01",
    "X-Requested-With" => "XMLHttpRequest"
  }
].freeze

# Query parameter variants to try on the base path
QUERY_PARAMS = [
  "",
  "?id=1",
  "?event_id=1",
  "?year=2025"
].freeze

# Endpoint paths to probe
PATHS = %w[
  /Reports/ViewAllRanks
  /Reports/ViewTimetable
  /Reports/ViewPlayers
].freeze

BASE_URL = "https://umbevents.umb-carom.org"

puts "=" * 60
puts "Probing umbevents.umb-carom.org"
puts "=" * 60

# Phase 1: Probe each path with all header combinations (no query params)
PATHS.each do |path|
  HEADER_VARIANTS.each_with_index do |headers, idx|
    label = "#{path.delete("/")}_headers#{idx}"
    probe(label, "#{BASE_URL}#{path}", headers)
  end
end

# Phase 2: Probe each path with query parameters (using JSON-requesting headers)
json_headers = { "Accept" => "application/json", "X-Requested-With" => "XMLHttpRequest" }

PATHS.each do |path|
  QUERY_PARAMS.each do |params|
    next if params.empty? # Already covered in phase 1

    label = "#{path.delete("/")}_#{params.delete("?").delete("=")}"
    probe(label, "#{BASE_URL}#{path}#{params}", json_headers)
  end
end

puts "\n" + "=" * 60
puts "Probe complete."
puts "Sample JSON responses (if any) saved to: #{SAMPLES_DIR}"
puts "=" * 60
