# frozen_string_literal: true

# ============================================================================
# Purge der <24/25-Rollover-Reste + Garbage-Datteln (Fortsetzung des 25/26-Purges).
#
# Zwei Regeln (Union):
#   R1) CC-copy-forward-Reste: Party mit sb_spielbericht-source_url, url-Saison < 2024/2025,
#       deren date NICHT in die url-Saison faellt (falsch einsortierte Alt-Begegnungen).
#       Hauptnest BVB 21/22 (319) + kleine Reste (TBV/BVNR/BVRP/BVS/BLVN/DBU).
#   R2) Garbage-Datteln: Party mit date < 1990-01-01 (0024/0003/1970 = Parsing-Garbage bzw.
#       Uralt-Records ohne source_url). Aelteste echte Season ist 2009/2010 -> date<1990 = kaputt.
#
# Sicherheit (wie 25/26-Purge):
#   - Default DRY-RUN. Echtes Loeschen nur mit ARMED=1. REGIONS-Filter optional.
#   - WICHTIG: Party.date ist TimeWithZone; Season#includes_date prueft is_a?(Date)
#     -> IMMER .to_date uebergeben (sonst faelschlich ALLE als mismatch).
#   - PartyGames explizit mitloeschen (kein dependent:destroy) -> keine Waisen; .destroy => Sync.
#   - Harte Assertions: R1-Opfer date∈url-Saison muss 0 sein; R2-Opfer date>=1990 muss 0 sein.
#
# Aufruf:
#   bin/rails runner scratchpad/purge_pre2425_rollover_and_garbage.rb            # dry-run
#   ARMED=1 bin/rails runner scratchpad/purge_pre2425_rollover_and_garbage.rb    # loeschen
#
# PROD: ssh api; cd current; export PATH=/var/www/.rbenv/shims:$PATH; RAILS_ENV=production
#   1. RAILS_ENV=production bin/rails runner scratchpad/purge_pre2425_rollover_and_garbage.rb   # dry-run: 350/2192
#   2. ARMED=1 RAILS_ENV=production bin/rails runner scratchpad/purge_pre2425_rollover_and_garbage.rb
# Kein Rescrape noetig (abgeschlossene Alt-Saisons; Cron zielt ohnehin auf current_season).
# Verifiziert auf Dev-Spiegel 2026-07-17: 350 Parties + 2192 PartyGames geloescht (BVB 319 + Reste),
# 0 Rest-mismatch, 0 Rest-Garbage, 0 Waisen, 78 echte BVB-21/22 erhalten.
# ============================================================================

ActiveRecord::Base.logger = nil
Rails.logger = Logger.new(File::NULL)

ARMED = ENV["ARMED"] == "1"
REGION_FILTER = ENV["REGIONS"].to_s.split(",").map(&:strip).reject(&:empty?)
GARBAGE_CUTOFF = Date.new(1990, 1, 1)
SEASON_CUTOFF = "2024/2025" # url-Saisons strikt kleiner werden betrachtet

seasons_by_name = Season.all.index_by(&:name)
reg_names = Region.pluck(:id, :shortname).to_h

# R1: sb_spielbericht, url-Saison < 24/25, date∉url-Saison
r1 = []
Party.where("source_url like ?", "%sb_spielbericht%").find_each do |p|
  us = p.source_url.to_s[%r{--(\d{4}/\d{4})}, 1]
  next unless us && us < SEASON_CUTOFF
  next if p.date.nil?
  s = seasons_by_name[us] or next
  next if s.includes_date(p.date.to_date) # date passt -> echt, behalten
  next if REGION_FILTER.any? && !REGION_FILTER.include?(reg_names[p.region_id])
  r1 << p
end

# R2: date < 1990 (unabhaengig von source_url)
r2 = Party.where("date < ?", GARBAGE_CUTOFF).to_a
r2.select! { |p| REGION_FILTER.include?(reg_names[p.region_id]) } if REGION_FILTER.any?

# Union
victims = (r1 + r2).uniq(&:id)
victim_ids = victims.map(&:id)
pg_counts = PartyGame.where(party_id: victim_ids).group(:party_id).count

puts "=" * 64
puts "PURGE <24/25-Reste + Garbage — #{ARMED ? "!!! ARMED (loescht) !!!" : "DRY-RUN"}"
puts "Region-Filter: #{REGION_FILTER.any? ? REGION_FILTER.join(",") : "(alle betroffenen)"}"
puts "=" * 64
puts "  R1 (date∉url-Saison, <24/25): #{r1.size} Parties"
puts "  R2 (date<1990 Garbage):       #{r2.size} Parties"
puts "  UNION:                        #{victims.size} Parties, #{pg_counts.values.sum} PartyGames"

puts "\n  je Region:"
victims.group_by { |p| reg_names[p.region_id] || p.region_id }.sort_by { |_r, v| -v.size }.each do |r, ps|
  pg = ps.sum { |p| pg_counts[p.id].to_i }
  puts format("    %-8s Parties=%4d  PartyGames=%5d", r, ps.size, pg)
end

# Sicherheits-Assertions
r1_leak = r1.count { |p| seasons_by_name[p.source_url.to_s[%r{--(\d{4}/\d{4})}, 1]]&.includes_date(p.date.to_date) }
r2_leak = r2.count { |p| p.date && p.date.to_date >= GARBAGE_CUTOFF }
puts "\n  SICHERHEIT R1 (date IN url-Saison, muss 0): #{r1_leak}"
puts "  SICHERHEIT R2 (date >= 1990, muss 0):       #{r2_leak}"
abort "ABBRUCH: Diskriminator-Leck!" if r1_leak.positive? || r2_leak.positive?

unless ARMED
  puts "\nDRY-RUN — nichts geloescht. Zum Loeschen: ARMED=1."
  puts "\nBeispiele R1:"
  r1.first(4).each { |p| puts "  [#{p.id}] date=#{p.date.to_date} #{p.source_url.to_s[/\?p=.*/]&.slice(0, 45)}" }
  puts "Beispiele R2 (Garbage):"
  r2.first(4).each { |p| puts "  [#{p.id}] date=#{p.date.to_date} reg=#{reg_names[p.region_id]} src=#{p.source_url.to_s[0, 40].inspect}" }
  return
end

# ARMED
puts "\nLoesche #{victims.size} Parties + #{pg_counts.values.sum} PartyGames …"
dp = 0
dpg = 0
victims.each_with_index do |p, i|
  ActiveRecord::Base.transaction do
    PartyGame.skip_cable_ready_updates do
      PartyGame.where(party_id: p.id).find_each { |pg| pg.destroy! and dpg += 1 }
    end
    Party.skip_cable_ready_updates { p.destroy! }
    dp += 1
  end
  puts "  … #{i + 1}/#{victims.size}" if ((i + 1) % 100).zero?
rescue => e
  puts "  FEHLER Party[#{p.id}]: #{e.class} #{e.message[0, 120]}"
end
puts "FERTIG: #{dp} Parties + #{dpg} PartyGames geloescht."
