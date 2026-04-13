# frozen_string_literal: true

# Throwaway probe script — NOT part of app/ — do not commit to production code
# Run with: bundle exec ruby tmp/probe_sooplive.rb
#
# Purpose: Probe billiards.sooplive.com for hidden JSON API endpoints behind
# jsRender-templated schedule pages. Uses URL pattern inference (Pattern C from
# RESEARCH.md) plus HTML inspection for inline API URL references.
# Results feed into Phase 24 findings document (24-FINDINGS.md).

require "net/http"
require "json"
require "uri"
require "openssl"
require "fileutils"

SAMPLES_DIR = File.expand_path("../samples/sooplive", __FILE__)
FileUtils.mkdir_p(SAMPLES_DIR)

# Copy of UmbScraperV2#fetch_url pattern — handles redirects, SSL, returns full response.
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
      # Return non-success responses for inspection
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
    return nil
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

  response
end

puts "=" * 60
puts "Probing billiards.sooplive.com (Pattern C — URL inference)"
puts "=" * 60

# --- Phase 1: Direct URL pattern guesses (from RESEARCH.md Pattern C) ---
puts "\n### Phase 1: API URL pattern guesses ###"

json_headers = {
  "Accept" => "application/json",
  "X-Requested-With" => "XMLHttpRequest"
}

# All six pattern guesses from the plan spec
url_guesses = [
  "https://billiards.sooplive.com/api/schedule/127",
  "https://billiards.sooplive.com/schedule/127/matches",
  "https://billiards.sooplive.com/schedule/127.json",
  "https://billiards.sooplive.com/api/schedule/127/matches",
  "https://billiards.sooplive.com/schedule/api/127",
  "https://api.sooplive.com/schedule/127"
]

url_guesses.each_with_index do |url, idx|
  # Try with default headers first, then with JSON headers
  probe("sooplive_guess#{idx + 1}_default", url)
  probe("sooplive_guess#{idx + 1}_json", url, json_headers)
end

# --- Phase 2: HTML inspection of the schedule page for API URL patterns ---
puts "\n### Phase 2: HTML inspection of schedule/127 for API URL references ###"

schedule_url = "https://billiards.sooplive.com/schedule/127?sub1=result"
puts "\nFetching #{schedule_url} for inline script inspection..."

response = fetch_url(schedule_url, { "Accept" => "text/html" })

if response
  body = response.body || ""
  puts "Status:  #{response.code}"
  puts "Content-Type: #{response["content-type"]}"
  puts "Body length: #{body.length} chars"

  # Look for API URL patterns in inline scripts
  puts "\n--- Searching for API URL patterns in HTML/inline scripts ---"

  # Patterns that reveal API endpoints
  api_patterns = [
    /fetch\s*\(\s*['"]([^'"]+)['"]/,
    /\$\.ajax\s*\(\s*\{[^}]*url\s*:\s*['"]([^'"]+)['"]/,
    /\$\.get\s*\(\s*['"]([^'"]+)['"]/,
    /\$\.post\s*\(\s*['"]([^'"]+)['"]/,
    /url\s*[:=]\s*['"]([^'"]*\/api\/[^'"]+)['"]/i,
    /url\s*[:=]\s*['"]([^'"]*\/schedule\/[^'"]+)['"]/i,
    /["']([^"']*\/api\/[^"']{3,})['"]/,
    /apiUrl\s*[=:]\s*['"]([^'"]+)['"]/i,
    /dataUrl\s*[=:]\s*['"]([^'"]+)['"]/i,
    /endpoint\s*[=:]\s*['"]([^'"]+)['"]/i
  ]

  found_patterns = []
  api_patterns.each do |pattern|
    matches = body.scan(pattern).flatten.uniq
    matches.each do |match|
      found_patterns << match
      puts "  FOUND API pattern: #{match}"
    end
  end

  puts "  (no API URL patterns found in HTML)" if found_patterns.empty?

  # Look for data-seq and data-broad_no attributes (jsRender template placeholders)
  puts "\n--- Checking for jsRender template placeholders ---"
  data_seq_matches = body.scan(/data-seq="([^"]+)"/).flatten.uniq
  broad_no_matches = body.scan(/data-broad_no="([^"]+)"/).flatten.uniq
  puts "  data-seq values: #{data_seq_matches.empty? ? "(none)" : data_seq_matches[0..2].inspect}"
  puts "  data-broad_no values: #{broad_no_matches.empty? ? "(none)" : broad_no_matches[0..2].inspect}"

  # Look for external script sources that might load API URLs
  puts "\n--- External script sources ---"
  script_srcs = body.scan(/<script[^>]+src="([^"]+)"/).flatten.uniq
  script_srcs.each { |src| puts "  Script: #{src}" }
  puts "  (no external scripts found)" if script_srcs.empty?

  # Look for any mentions of 'api', 'json', 'ajax', 'endpoint' in the source
  puts "\n--- Keyword search: api/json/ajax/endpoint in HTML ---"
  api_keyword_lines = body.split("\n").select { |line| line.match?(/\b(api|ajax|fetch|endpoint|\.json)\b/i) }
  if api_keyword_lines.empty?
    puts "  (no api/ajax/json keyword lines found)"
  else
    api_keyword_lines.first(10).each { |line| puts "  #{line.strip[0..200]}" }
  end

  # Look for jsRender template script blocks
  puts "\n--- jsRender template blocks ---"
  template_blocks = body.scan(/<script[^>]*type="text\/x-jsrender"[^>]*>(.*?)<\/script>/m).flatten
  if template_blocks.empty?
    puts "  (no jsRender template blocks found)"
  else
    template_blocks.first(2).each { |block| puts "  Template block: #{block.strip[0..300]}" }
  end
else
  puts "Failed to fetch schedule page"
end

puts "\n" + "=" * 60
puts "Probe complete."
puts "Sample JSON responses (if any) saved to: #{SAMPLES_DIR}"
puts "=" * 60
