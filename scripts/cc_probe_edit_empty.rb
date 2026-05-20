# frozen_string_literal: true
# Hypothesis: editMeldelisteCheck mit edit= (LEER) lädt DB-State in Server-Scratch.
# edit="1" triggert das NICHT — daher Tool-Re-Add nötig.
# Test: Browser-Replay des Init-Calls + 1 cc_add(neuer) + save + verify.

require "net/http"
require "uri"

MID    = 1310
FED    = 20
BRANCH = 8
SEASON = "2025/2026"
NEW_PLAYER = 10031  # aus Probe-Log — sollte aktuell NICHT in Liste sein
NEW_CLUB = 1010    # cc_id für 10031 vermutlich BC Wedel; ggf. ohne Bestätigung

base_url = McpServer::CcSession.client_for.instance_variable_get(:@base_url)
cookie = McpServer::CcSession.cookie

direct_post = ->(path, body_pairs, label) {
  uri = URI(base_url + path)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  req = Net::HTTP::Post.new(uri.request_uri)
  req["cookie"] = "PHPSESSID=#{cookie}"
  req["Content-Type"] = "application/x-www-form-urlencoded"
  req.body = body_pairs.map { |k, v| "#{k}=#{URI.encode_www_form_component(v.to_s)}" }.join("&")
  res = http.request(req)
  puts "  [#{label}] HTTP #{res.code} #{res.body.bytesize}B"
  res.body.to_s
}

verify = ->(label) {
  # use library post (read-only, blank-filter ok)
  client = McpServer::CcSession.client_for
  res, _doc = client.post("showCommittedMeldeliste",
    {clubId: "*", fedId: FED, branchId: BRANCH, disciplinId: "*", catId: "*",
     season: SEASON, meldelisteId: MID, sortOrder: "player"},
    {armed: true, session_id: cookie})
  body = res&.body.to_s
  drin = body.scan(/<td align=['"]center['"]>(\d+)<\/td>/).flatten.map(&:to_i)
  puts "  [#{label}] committed players: #{drin.inspect}"
  drin
}

puts "=" * 70
puts "Test: editMeldelisteCheck(edit=LEER) lädt Scratch aus DB?"
puts "=" * 70

before = verify.("before")

puts "\n--- Step 1: Browser-Replay Init Call (edit= LEER) ---"
direct_post.(
  "/admin/myclub/meldewesen/single/editMeldelisteCheck.php",
  [
    ["fedId", FED], ["disciplinId", "*"], ["season", SEASON], ["catId", "*"],
    ["meldelisteId", MID], ["sortOrder", "player"], ["clubId", NEW_CLUB],
    ["branchId", BRANCH], ["edit", ""]   # LEER!
  ],
  "init edit=LEER"
)

puts "\n--- Step 2: cc_add NEW player #{NEW_PLAYER} (club #{NEW_CLUB}) ---"
direct_post.(
  "/admin/myclub/meldewesen/single/cc_add.php",
  [
    ["clubId", NEW_CLUB], ["fedId", FED], ["branchId", BRANCH],
    ["disciplinId", "*"], ["catId", "*"], ["season", SEASON],
    ["meldelisteId", MID], ["firstEntry", 1], ["rang", 1],
    ["selectedClubId", NEW_CLUB], ["a", NEW_PLAYER]
  ],
  "cc_add #{NEW_PLAYER}"
)

puts "\n--- Step 3: saveMeldeliste ---"
direct_post.(
  "/admin/myclub/meldewesen/single/editMeldelisteSave.php",
  [
    ["clubId", NEW_CLUB], ["fedId", FED], ["branchId", BRANCH],
    ["disciplinId", "*"], ["catId", "*"], ["season", SEASON],
    ["meldelisteId", MID], ["firstEntry", 1], ["rang", 1],
    ["selectedClubId", NEW_CLUB], ["a", NEW_PLAYER], ["save", "1"]
  ],
  "save"
)

puts "\n--- Step 4: Verify ---"
after = verify.("after")

puts "\nFAZIT:"
preserved = (before & after) - [NEW_PLAYER]
lost = before - after
puts "- Vorher drin: #{before.inspect}"
puts "- Nachher drin: #{after.inspect}"
puts "- Bewahrt: #{preserved.inspect}"
puts "- Verloren: #{lost.inspect}"
puts "- Neuer Spieler #{NEW_PLAYER} drin? #{after.include?(NEW_PLAYER) ? "✅" : "❌"}"
puts
if lost.empty? && after.include?(NEW_PLAYER)
  puts "🎯 HYPOTHESE BESTÄTIGT: edit=LEER lädt DB-State in Scratch automatisch."
elsif !after.include?(NEW_PLAYER) && lost.empty?
  puts "⚠️ Add hat nicht gegriffen — Sequenz-Problem"
else
  puts "❌ HYPOTHESE FALSCH: edit=LEER lädt nicht. Players verloren: #{lost.inspect}"
end
puts "=" * 70
