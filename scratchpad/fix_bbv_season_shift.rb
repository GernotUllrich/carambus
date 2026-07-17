# frozen_string_literal: true

# ============================================================================
# Fix: BBV-Ligen-Saison-Verschiebung zurueckdrehen (23/24 → 21/22).
#
# Ursache (vom User geklaert): 2021/22 gab es noch einen BBV-CC-Server, normal
# per cc-Scraper geholt. In den Folgejahren wurde die Liga-Saison faelschlich
# jaehrlich um 1 weitergeschoben (→ landete bei 2023/24), die Objekte (Parties/
# Teams/PartyGames) blieben dran. Die 86 „23/24"-BBV-Ligen tragen ausschliesslich
# 21/22-Datteln (Sep 2021–Jun 2022). Party/LeagueTeam haben KEIN eigenes season_id
# → nur league.season_id zuruecksetzen reicht.
#
# Diskriminator (3-fach): organizer=Region:BBV UND season=2023/2024 UND source_url IS NULL
# (die echten NuLiga-Ligen tragen source_url — die bleiben unberuehrt).
#
# Sicherheit: Default DRY-RUN, ARMED=1. Assertions: (a) jede betroffene Liga hat NUR
# Parties mit date∈21/22 (keine fremde Saison); (b) keine Namens-Kollision mit
# bestehender 21/22-BBV-Liga. Update broadcast-frei (skip_cable_ready) → PaperTrail → Sync.
# REVERSIBEL (season zurueckstellbar). Danach separat: echte 23/24 aus NuLiga scrapen.
#
# Aufruf:
#   bin/rails runner scratchpad/fix_bbv_season_shift.rb            # dry-run
#   ARMED=1 bin/rails runner scratchpad/fix_bbv_season_shift.rb    # anwenden
# ============================================================================

ActiveRecord::Base.logger = nil
Rails.logger = Logger.new(File::NULL)

ARMED = ENV["ARMED"] == "1"
bbv = Region.find_by(shortname: "BBV") or abort "BBV fehlt"
s_from = Season.find_by(name: "2023/2024") or abort "Season 2023/2024 fehlt"
s_to = Season.find_by(name: "2021/2022") or abort "Season 2021/2022 fehlt"

leagues = League.where(season_id: s_from.id, organizer_type: "Region", organizer_id: bbv.id)
  .where(source_url: nil).to_a

puts "=" * 64
puts "FIX BBV Saison-Shift 2023/2024 → 2021/2022 — #{ARMED ? "!!! ARMED !!!" : "DRY-RUN"}"
puts "=" * 64
puts "  Betroffene BBV-Ligen (organizer=BBV, season=23/24, source_url nil): #{leagues.size}"

# --- Assertions ---
bad_dates = []
leagues.each do |l|
  ps = Party.where(league_id: l.id).to_a
  outside = ps.count { |p| p.date.nil? || !s_to.includes_date(p.date.to_date) }
  bad_dates << [l.id, l.name, outside] if outside.positive?
end
existing_names = League.where(season_id: s_to.id, organizer_type: "Region", organizer_id: bbv.id)
  .pluck(:name, :staffel_text).to_set
collisions = leagues.select { |l| existing_names.include?([l.name, l.staffel_text]) }

total_parties = Party.where(league_id: leagues.map(&:id)).count
puts "  Parties gesamt an diesen Ligen: #{total_parties}"
puts "  Disziplinen: #{leagues.group_by { |l| l.discipline&.name }.transform_values(&:size)}"
puts "\n  SICHERHEIT a) Ligen mit Party date∉21/22 (muss 0): #{bad_dates.size}"
bad_dates.first(5).each { |id, n, o| puts "     [#{id}] #{n} — #{o} Parties ausserhalb" }
puts "  SICHERHEIT b) Namens-Kollision mit bestehender 21/22-BBV-Liga (muss 0): #{collisions.size}"
if bad_dates.any? || collisions.any?
  abort "ABBRUCH: Sicherheits-Assertion verletzt"
end

unless ARMED
  puts "\nDRY-RUN — nichts geaendert. Beispiele:"
  leagues.first(8).each { |l| puts format("  [%d] %-30s disc=%s Parties=%d", l.id, l.name.to_s[0, 28], l.discipline&.name, Party.where(league_id: l.id).count) }
  puts "\nZum Anwenden: ARMED=1. Danach echte 23/24 aus NuLiga scrapen."
  return
end

# --- ARMED: season_id umsetzen. save(validate:false), weil Alt-Ligen die NEUERE
# shortname-Pflicht (organizer=Region) nicht erfuellen; wir aendern NUR season_id.
# save behaelt Callbacks → PaperTrail → Sync; broadcast via skip_cable_ready unterdrueckt.
puts "\nSetze season_id → 2021/2022 …"
done = 0
failed = 0
leagues.each do |l|
  l.season_id = s_to.id
  ok = League.skip_cable_ready_updates { l.save(validate: false) }
  ok ? (done += 1) : (failed += 1)
rescue => e
  failed += 1
  puts "  FEHLER Liga[#{l.id}] #{l.name}: #{e.class} #{e.message[0, 140]}"
end
suffix = failed.positive? ? " (#{failed} FEHLER)" : ""
puts "FERTIG: #{done} BBV-Ligen von 2023/2024 → 2021/2022 verschoben#{suffix}."
