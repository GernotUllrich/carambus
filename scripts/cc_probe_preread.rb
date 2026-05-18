# frozen_string_literal: true

# Test: Füllt showCommittedMeldeliste den Server-Scratch mit DB-State?
# Sequenz: pre-read → cc_add(Balzer) → save → verify
# Erwartung wenn ja: nach save sind {Nachtmann, Balzer} drin (Merge)
# Erwartung wenn nein: nach save ist nur {Balzer} drin (Overwrite)

MID    = 1310
CLUB   = 1042  # Balzer's Club (TUS Neuendorf)
PLAYER = 10358 # Balzer
FED    = 20
BRANCH = 8
SEASON = "2025/2026"

client = McpServer::CcSession.client_for
cookie = McpServer::CcSession.cookie

post = ->(action, payload, label = nil) {
  t0 = Time.now
  res, _doc = client.post(action, payload, {armed: true, session_id: cookie})
  dt = ((Time.now - t0) * 1000).round
  body = res&.body.to_s
  puts "  [#{label || action}] HTTP #{res&.code} #{body.bytesize}B #{dt}ms"
  body
}

verify = ->(label) {
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
puts "Pre-Read-Fills-Scratch Test"
puts "MID=#{MID} adding PLAYER=#{PLAYER} (Balzer, Club #{CLUB})"
puts "=" * 70

puts "\n--- Step 1: Pre-Read (showCommittedMeldeliste — sollte Scratch füllen falls Hypothese) ---"
verify.("before")

puts "\n--- Step 2: cc_add Balzer ---"
post.("addPlayerToMeldeliste",
  {clubId: CLUB, fedId: FED, branchId: BRANCH, disciplinId: "*", catId: "*",
   season: SEASON, meldelisteId: MID, firstEntry: 1, rang: 1,
   selectedClubId: CLUB, a: PLAYER}, "cc_add Balzer")

puts "\n--- Step 3: saveMeldeliste ---"
post.("saveMeldeliste",
  {clubId: CLUB, fedId: FED, branchId: BRANCH, disciplinId: "*", catId: "*",
   season: SEASON, meldelisteId: MID, firstEntry: 1, rang: 1,
   selectedClubId: CLUB, a: PLAYER, save: "1"}, "save")

puts "\n--- Step 4: Final Verify ---"
result = verify.("after")
puts "\nFAZIT:"
puts "- Nachtmann (11683) noch drin? #{result.include?(11683) ? "JA → Pre-Read füllt Scratch ✅" : "NEIN → Overwrite-Bug ❌"}"
puts "- Balzer (10358) drin? #{result.include?(10358) ? "JA ✅" : "NEIN ❌"}"
puts "=" * 70
