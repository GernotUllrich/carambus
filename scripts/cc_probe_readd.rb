# frozen_string_literal: true

# Hypothesis-2 Test: Re-Add-Loop für alle (existing + new) Players, dann save.
# Sequenz: init-check → für jeden Player: check(a=pid) + cc_add(a=pid) → save → verify

MID    = 1310
FED    = 20
BRANCH = 8
SEASON = "2025/2026"

# Players to ensure are committed: Nachtmann(BC Wedel), Balzer(TUS), Dürr(TUS)
TARGETS = [
  {pid: 11683, club: 1010, name: "Nachtmann"},
  {pid: 10358, club: 1042, name: "Balzer"},
  {pid: 11880, club: 1042, name: "Dürr"}
]

client = McpServer::CcSession.client_for
cookie = McpServer::CcSession.cookie

post = ->(action, payload, label = nil) {
  res, _doc = client.post(action, payload, {armed: true, session_id: cookie})
  body = res&.body.to_s
  puts "  [#{label || action}] HTTP #{res&.code} #{body.bytesize}B"
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
puts "Re-Add-Strategy Test: alle 3 Players (Nachtmann/Balzer/Dürr) ensure"
puts "=" * 70

verify.("before")

# Init-Edit-Mode für die Meldeliste (use first player's club als clubId fürs init)
# CLUB-Wahl: Nachtmann 1010 ist sportwart-club aus dem Probe, das hatte funktioniert
INIT_CLUB = 1010
puts "\n--- Init Edit-Mode (clubId=#{INIT_CLUB}) ---"
post.("sportwart-editMeldelisteCheck",
  {clubId: INIT_CLUB, fedId: FED, branchId: BRANCH, disciplinId: "*", catId: "*",
   season: SEASON, meldelisteId: MID, firstEntry: 1, selectedClubId: INIT_CLUB,
   sortOrder: "player", edit: "1"}, "init-check")

puts "\n--- Per-Player Check + cc_add ---"
TARGETS.each do |t|
  puts "Player #{t[:name]} (#{t[:pid]}, club #{t[:club]}):"
  # Check mit player-spezifischem selectedClubId
  post.("sportwart-editMeldelisteCheck",
    {fedId: FED, branchId: BRANCH, disciplinId: "*", catId: "*",
     season: SEASON, meldelisteId: MID, firstEntry: 1,
     selectedClubId: t[:club], a: t[:pid]}, "  check #{t[:name]}")
  # Add mit player-club
  post.("addPlayerToMeldeliste",
    {clubId: t[:club], fedId: FED, branchId: BRANCH, disciplinId: "*", catId: "*",
     season: SEASON, meldelisteId: MID, firstEntry: 1, rang: 1,
     selectedClubId: t[:club], a: t[:pid]}, "  add #{t[:name]}")
end

puts "\n--- Save ---"
last = TARGETS.last
post.("saveMeldeliste",
  {clubId: last[:club], fedId: FED, branchId: BRANCH, disciplinId: "*", catId: "*",
   season: SEASON, meldelisteId: MID, firstEntry: 1, rang: 1,
   selectedClubId: last[:club], a: last[:pid], save: "1"}, "save")

puts "\n--- Verify ---"
result = verify.("after")
puts "\nFAZIT:"
TARGETS.each do |t|
  puts "- #{t[:name]} (#{t[:pid]}): #{result.include?(t[:pid]) ? "✅ drin" : "❌ FEHLT"}"
end
puts "=" * 70
