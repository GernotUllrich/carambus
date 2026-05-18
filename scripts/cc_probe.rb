# frozen_string_literal: true

# CC-Probe: direkter Sequenz-Test gegen Live-CC, ohne MCP-Tool-Roundtrip.
# Use: bin/rails runner scripts/cc_probe.rb [pattern] [meldeliste] [club] [player_ids,...]
#
# Patterns:
#   h2  - Init Check + N×(Add + Echo-Check) + Save                 (HAR-Sequenz)
#   h3  - Init Check + N×(Check + Add) + Save                      (Check-vor-Add)
#   raw - N×Add + Save                                              (kein Check)
#   har - HAR-Replay byte-für-byte (clubId=1011, gd=, d=, save= leer, setzNummer=)
#
# Beispiele:
#   bin/rails runner scripts/cc_probe.rb h2  1310 1010 11683,10031,10032
#   bin/rails runner scripts/cc_probe.rb har 1310 1011 10338,10013

PATTERN  = (ARGV[0] || "h2").to_sym
MID      = (ARGV[1] || "1310").to_i
CLUB     = (ARGV[2] || "1010").to_i
PLAYERS  = (ARGV[3] || "11683,10031,10032").split(",").map(&:to_i)
FED      = 20
BRANCH   = 8
SEASON   = "2025/2026"

# ------------------------------------------------------------------------------
# Setup
client = McpServer::CcSession.client_for
cookie = McpServer::CcSession.cookie
puts "=" * 80
puts "CC-Probe pattern=#{PATTERN} mid=#{MID} club=#{CLUB} players=#{PLAYERS.inspect}"
puts "Session: cookie=#{cookie.to_s[0, 30]}... base_url=#{client.instance_variable_get(:@base_url)}"
puts "=" * 80

step = 0
post = ->(action, payload, label = nil) {
  step += 1
  t0 = Time.now
  res, _doc = client.post(action, payload, {armed: true, session_id: cookie})
  dt = ((Time.now - t0) * 1000).round
  body = res&.body.to_s
  preview = body.gsub(/\s+/, " ").strip[0, 180]
  err_match = body.match(/<font color="red">([^<]+)<\/font>|<div class="error[^"]*"[^>]*>([^<]+)<\/div>/)
  err = err_match && (err_match[1] || err_match[2])
  marker = err ? "❌" : "✅"
  puts "[#{step}] #{marker} #{action}#{label ? " (#{label})" : ""} → HTTP #{res&.code} #{body.bytesize}B #{dt}ms"
  puts "    payload: #{payload.inspect}"
  puts "    preview: #{preview}" if body.bytesize < 2000
  puts "    error  : #{err}" if err
  body
}

verify = -> {
  step += 1
  res, _doc = client.post("showCommittedMeldeliste",
    {clubId: "*", fedId: FED, branchId: BRANCH, disciplinId: "*", catId: "*",
     season: SEASON, meldelisteId: MID, sortOrder: "player"},
    {armed: true, session_id: cookie})
  body = res&.body.to_s
  drin = body.scan(/<td align=['"]center['"]>(\d+)<\/td>/).flatten.map(&:to_i)
  marker = (PLAYERS - drin).empty? ? "✅" : "⚠️"
  puts "[#{step}] #{marker} VERIFY showCommittedMeldeliste → players in list: #{drin.inspect}"
  puts "    expected: #{PLAYERS.inspect}  missing: #{(PLAYERS - drin).inspect}  extra: #{(drin - PLAYERS).inspect}"
  drin
}

# Cleanup: Vorab Liste leeren (falls Reste)
puts "\n--- CLEANUP ---"
already = verify.()
already.each do |pid|
  next unless PLAYERS.include?(pid)
  post.("removePlayerFromMeldeliste",
    {clubId: CLUB, fedId: FED, branchId: BRANCH, disciplinId: "*", catId: "*",
     season: SEASON, meldelisteId: MID, firstEntry: 1, rang: 1,
     selectedClubId: CLUB, a: pid, d: pid}, "cleanup")
  post.("saveMeldeliste",
    {clubId: CLUB, fedId: FED, branchId: BRANCH, disciplinId: "*", catId: "*",
     season: SEASON, meldelisteId: MID, firstEntry: 1, rang: 1,
     selectedClubId: CLUB, a: pid, save: "1"}, "cleanup-save")
end
verify.()

# Standard-Payloads
base_full = {
  clubId: CLUB, fedId: FED, branchId: BRANCH, disciplinId: "*", catId: "*",
  season: SEASON, meldelisteId: MID, firstEntry: 1, rang: 1, selectedClubId: CLUB
}
check_min = {
  fedId: FED, branchId: BRANCH, disciplinId: "*", catId: "*",
  season: SEASON, meldelisteId: MID, firstEntry: 1, selectedClubId: CLUB
}

puts "\n--- SEQUENCE (#{PATTERN}) ---"
case PATTERN
when :h2
  post.("sportwart-editMeldelisteCheck",
    check_min.merge(clubId: CLUB, sortOrder: "player", edit: "1"), "init")
  PLAYERS.each do |pid|
    post.("addPlayerToMeldeliste", base_full.merge(a: pid), "add")
    post.("sportwart-editMeldelisteCheck", check_min.merge(a: pid), "echo")
  end
  post.("saveMeldeliste", base_full.merge(a: PLAYERS.last, save: "1"), "save")

when :h3
  post.("sportwart-editMeldelisteCheck",
    check_min.merge(clubId: CLUB, sortOrder: "player", edit: "1"), "init")
  PLAYERS.each do |pid|
    post.("sportwart-editMeldelisteCheck", check_min.merge(a: pid), "pre")
    post.("addPlayerToMeldeliste", base_full.merge(a: pid), "add")
  end
  post.("saveMeldeliste", base_full.merge(a: PLAYERS.last, save: "1"), "save")

when :raw
  PLAYERS.each { |pid| post.("addPlayerToMeldeliste", base_full.merge(a: pid), "add") }
  post.("saveMeldeliste", base_full.merge(a: PLAYERS.last, save: "1"), "save")

when :har
  # HAR-Replay: clubId=1011, save= LEER (Sentinel " "), kein .reject(&:blank?) Workaround
  # nicht trivial — daher dies eine LOG-Reference. Echte HAR-Replay würde post_options-Filter
  # umgehen müssen.
  puts "HAR-Replay nicht 1:1 möglich ohne post-Filter-Bypass. Workaround: H2 mit club=1011 testen."
  exit 1
else
  puts "Unbekanntes Pattern: #{PATTERN}. Verwende h2|h3|raw."
  exit 1
end

puts "\n--- FINAL VERIFY ---"
verify.()
puts "=" * 80
