# frozen_string_literal: true

# ============================================================================
# Purge der 25/26-Rollover-Kopien (CC copy-forward).
#
# Diskriminator: Party mit sb_spielbericht-source_url, deren url-Saison "2025/2026"
# ist, deren tatsaechliches date aber NICHT in die Saison 2025/2026 faellt.
# Das trifft exakt die kopierten Alt-Begegnungen (Datum aus 2009-2024), NIE
# echte 25/26-Begegnungen (date in Saison) und NIE ungespielte (date nil).
#
# Sicherheit:
#   - Default DRY-RUN. Echtes Loeschen nur mit ARMED=1.
#   - REGIONS=BVS,NBV  (Komma-Liste; default = alle betroffenen)
#   - Loescht PartyGames explizit mit (kein dependent:destroy auf party_games!),
#     damit keine Waisen bleiben; .destroy => PaperTrail-Version => Sync-Replikation.
#   - Harte Assertion pro Party: date vorhanden UND ausserhalb 2025/2026, sonst skip.
#
# Aufruf:
#   bin/rails runner scratchpad/purge_rollover_copies_2526.rb                 # dry-run
#   ARMED=1 bin/rails runner scratchpad/purge_rollover_copies_2526.rb         # loeschen
#   ARMED=1 REGIONS=BVS bin/rails runner scratchpad/purge_rollover_copies_2526.rb
#
# PROD-RUNBOOK (Authority carambus_api; repliziert via PaperTrail an Regional-Server):
#   0. Restore-Punkt: rake 'scenario:sync_production_db[carambus_api]' (carambus_master)
#   1. ssh api; cd .../current; export PATH=/var/www/.rbenv/shims:$PATH; export RAILS_ENV=production
#   2. bin/rails runner scratchpad/purge_rollover_copies_2526.rb           # DRY-RUN pruefen (~3322/23190)
#   3. ARMED=1 bin/rails runner scratchpad/purge_rollover_copies_2526.rb   # loeschen
#   4. BVS-Rescrape (Season 2025/2026 EXPLIZIT — current_season=2026/27 ist bei BVS nicht im CC-Selektor):
#      bin/rails runner 'League.scrape_leagues_from_cc(Region.find_by_shortname("BVS"), \
#        Season.find_by_name("2025/2026"), league_details: true, optimize_api_access: false)'
#      (laeuft durch den Rollover-Guard: BVS hat 25/26 im Selektor -> SCRAPE; idempotenter Upsert)
#   5. Verifikation: verbleibende date∉25/26-Kopien = 0; echte 25/26 intakt; Sync an carambus.de.
# Verifiziert auf Dev-Spiegel 2026-07-17: 3322 Parties + 23190 PartyGames, 0 Waisen, 0 Restkopien,
# 11097 echte 25/26 intakt, Rescrape reproduziert KEINE Kopien.
# ============================================================================

ActiveRecord::Base.logger = nil
Rails.logger = Logger.new(File::NULL)

ARMED = ENV["ARMED"] == "1"
REGION_FILTER = ENV["REGIONS"].to_s.split(",").map(&:strip).reject(&:empty?)

TARGET_SEASON_NAME = "2025/2026"
target_season = Season.find_by(name: TARGET_SEASON_NAME) or abort "Season #{TARGET_SEASON_NAME} fehlt"
reg_names = Region.pluck(:id, :shortname).to_h

# Kandidaten: url-Saison 2025/2026, sb_spielbericht
scope = Party.where("source_url like ?", "%sb_spielbericht%")
  .where("source_url like ?", "%#{TARGET_SEASON_NAME}%")

# WICHTIG: Party.date ist TimeWithZone. Season#includes_date prueft date.is_a?(Date)
# und gibt fuer TimeWithZone IMMER false -> IMMER .to_date uebergeben!
victims = []
scope.find_each do |p|
  us = p.source_url.to_s[%r{--(\d{4}/\d{4})}, 1]
  next unless us == TARGET_SEASON_NAME              # url-Saison muss exakt 25/26 sein
  next if p.date.nil?                               # ungespielt -> niemals anfassen
  next if target_season.includes_date(p.date.to_date) # echtes 25/26-Datum -> behalten
  next if REGION_FILTER.any? && !REGION_FILTER.include?(reg_names[p.region_id])
  victims << p
end

# Report
by_region = Hash.new { |h, k| h[k] = {parties: 0, pgs: 0} }
victim_ids = victims.map(&:id)
pg_counts = PartyGame.where(party_id: victim_ids).group(:party_id).count
victims.each do |p|
  r = reg_names[p.region_id] || p.region_id
  by_region[r][:parties] += 1
  by_region[r][:pgs] += pg_counts[p.id].to_i
end

puts "=" * 64
puts "PURGE 25/26-Rollover-Kopien — #{ARMED ? "!!! ARMED (loescht) !!!" : "DRY-RUN"}"
puts "Region-Filter: #{REGION_FILTER.any? ? REGION_FILTER.join(",") : "(alle betroffenen)"}"
puts "=" * 64
by_region.sort_by { |_r, h| -h[:parties] }.each do |r, h|
  puts format("  %-8s Parties=%5d  PartyGames=%6d", r, h[:parties], h[:pgs])
end
puts "-" * 64
puts format("  %-8s Parties=%5d  PartyGames=%6d", "GESAMT", victims.size, pg_counts.values.sum)

# Datums-Jahr-Verteilung (Kontrolle: darf kein 2025/2026-Datum enthalten)
yrs = victims.group_by { |p| p.date.year }.transform_values(&:size).sort.to_h
puts "  Datums-Jahre der Opfer: #{yrs.inspect}"
in_season_leak = victims.count { |p| target_season.includes_date(p.date.to_date) }
puts "  SICHERHEIT: Opfer mit Datum IN 25/26 (muss 0 sein): #{in_season_leak}"
abort "ABBRUCH: Diskriminator-Leck!" if in_season_leak.positive?

unless ARMED
  puts "\nDRY-RUN — nichts geloescht. Zum Loeschen: ARMED=1 (ggf. REGIONS=…)."
  # 5 Beispiele
  puts "\nBeispiele:"
  victims.first(5).each { |p| puts "  [#{p.id}] date=#{p.date.to_date} pgs=#{pg_counts[p.id].to_i} #{p.source_url[/\?p=.*/]}" }
  return
end

# ---- ARMED: loeschen (broadcast-frei; PaperTrail-destroy => Sync) ----
puts "\nLoesche #{victims.size} Parties + #{pg_counts.values.sum} PartyGames …"
deleted_p = 0
deleted_pg = 0
victims.each_with_index do |p, i|
  ActiveRecord::Base.transaction do
    PartyGame.skip_cable_ready_updates do
      PartyGame.where(party_id: p.id).find_each do |pg|
        pg.destroy!
        deleted_pg += 1
      end
    end
    Party.skip_cable_ready_updates { p.destroy! }
    deleted_p += 1
  end
  puts "  … #{i + 1}/#{victims.size}" if ((i + 1) % 500).zero?
rescue => e
  puts "  FEHLER bei Party[#{p.id}]: #{e.class} #{e.message[0, 120]}"
end
puts "FERTIG: #{deleted_p} Parties + #{deleted_pg} PartyGames geloescht."
