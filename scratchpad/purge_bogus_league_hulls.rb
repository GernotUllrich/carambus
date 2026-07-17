# frozen_string_literal: true

# ============================================================================
# Purge falsch angelegter Liga-Huellen (CC-Alt-Ligen unter falscher Saison).
#
# Kontext: Beim BVB-Scrape wurde season 2021/2022 mit der kompletten historischen
# Liga-Liste angelegt — cc_ids aus 2009-2017, die CC unter dem 21/22-Label liefert
# (CC ignoriert den Saison-Parameter fuer diese Alt-cc_ids). Die kontaminierten
# Begegnungen sind bereits gepurgt (date∉Saison); zurueck bleiben leere/date-nil-
# Liga-Huellen samt LeagueTeams/Seedings. Diese Ligen sind NICHT rescrapebar.
#
# Diskriminator: League der Ziel-Region+Saison OHNE eine einzige Party mit date∈Saison
# = falsche Huelle. Ligen MIT echter Saison-Party (legitim) bleiben unangetastet.
#
# Loescht je falscher Liga (in Abhaengigkeitsreihenfolge, broadcast-frei, PaperTrail=>Sync):
#   1. Parties (+ PartyGames explizit — kein dependent:destroy) der Liga
#   2. LeagueTeams (kaskadiert seedings + league_team_cc via dependent:destroy)
#   3. League (kaskadiert league_cc; game_plan nur nullify)
#
# Sicherheit: Default DRY-RUN, ARMED=1. Harte Assertions: (a) keine Opfer-Liga hat
# eine echte Saison-Party; (b) keine Opfer-Liga hat tournaments; (c) kein Opfer-
# LeagueTeam wird von Parties AUSSERHALB der Opfer-Ligen referenziert.
#
# Parametrisierbar: REGION=BVB SEASON=2021/2022 (Defaults). Aufruf:
#   bin/rails runner scratchpad/purge_bogus_league_hulls.rb            # dry-run
#   ARMED=1 bin/rails runner scratchpad/purge_bogus_league_hulls.rb    # loeschen
# PROD: ssh api; cd current; export PATH=/var/www/.rbenv/shims:$PATH; RAILS_ENV=production
# Verifiziert Dev-Spiegel 2026-07-17: 74 Ligen/152 LeagueTeams/330 Seedings/97 Parties weg,
# 3 legitime BVB-21/22-Ligen erhalten, 0 neue Waisen (Seedings/PartyGames/LeagueTeams).
# HINWEIS: pre-existing 3379 LeagueTeams mit toter league_id (region_id nil) sind ALT und
# NICHT von diesem Purge — separates Thema, hier nicht adressiert.
# ============================================================================

ActiveRecord::Base.logger = nil
Rails.logger = Logger.new(File::NULL)

ARMED = ENV["ARMED"] == "1"
REGION_SHORT = ENV["REGION"].presence || "BVB"
SEASON_NAME = ENV["SEASON"].presence || "2021/2022"

region = Region.find_by(shortname: REGION_SHORT) or abort "Region #{REGION_SHORT} fehlt"
season = Season.find_by(name: SEASON_NAME) or abort "Season #{SEASON_NAME} fehlt"

leagues = League.where(region_id: region.id, season_id: season.id).to_a

def has_real_party?(league, season)
  Party.where(league_id: league.id).any? { |p| p.date && season.includes_date(p.date.to_date) }
end

legit, bogus = leagues.partition { |l| has_real_party?(l, season) }
bogus_ids = bogus.map(&:id)
lt_ids = LeagueTeam.where(league_id: bogus_ids).pluck(:id)
seed_n = Seeding.where(league_team_id: lt_ids).count
party_ids = Party.where(league_id: bogus_ids).pluck(:id)
pg_n = PartyGame.where(party_id: party_ids).count

puts "=" * 64
puts "PURGE falsche Liga-Huellen #{REGION_SHORT} #{SEASON_NAME} — #{ARMED ? "!!! ARMED !!!" : "DRY-RUN"}"
puts "=" * 64
puts "  Ligen gesamt: #{leagues.size} → legitim=#{legit.size}, FALSCH=#{bogus.size}"
puts "  Zu loeschen: #{bogus.size} Ligen, #{lt_ids.size} LeagueTeams, #{seed_n} Seedings, " \
     "#{party_ids.size} Parties (#{pg_n} PartyGames)"
puts "  Legitim (behalten): #{legit.map { |l| l.name.to_s[0, 22] }.inspect}"

# --- Sicherheits-Assertions ---
leak_real = bogus.count { |l| has_real_party?(l, season) }
with_tourn = bogus.select { |l| l.tournaments.exists? }
ext_refs = Party.where(league_team_a_id: lt_ids).or(Party.where(league_team_b_id: lt_ids))
  .where.not(league_id: bogus_ids).count
puts "\n  SICHERHEIT a) Opfer mit echter Saison-Party (muss 0): #{leak_real}"
puts "  SICHERHEIT b) Opfer-Ligen mit tournaments (muss 0):    #{with_tourn.size}"
puts "  SICHERHEIT c) Opfer-LeagueTeams extern referenziert (muss 0): #{ext_refs}"
if leak_real.positive? || with_tourn.any? || ext_refs.positive?
  detail = with_tourn.any? ? " (tournaments an Liga #{with_tourn.map(&:id)})" : ""
  abort "ABBRUCH: Sicherheits-Assertion verletzt#{detail}"
end

unless ARMED
  puts "\nDRY-RUN — nichts geloescht. Beispiele falscher Huellen:"
  bogus.first(8).each do |l|
    puts format("  [%d] %-28s cc_id=%-4s Teams=%d", l.id, l.name.to_s[0, 26], l.cc_id,
      LeagueTeam.where(league_id: l.id).count)
  end
  puts "\nZum Loeschen: ARMED=1."
  return
end

# --- ARMED ---
puts "\nLoesche …"
dl = dlt = dp = 0
bogus.each_with_index do |league, i|
  ActiveRecord::Base.transaction do
    Party.where(league_id: league.id).find_each do |p|
      PartyGame.skip_cable_ready_updates { PartyGame.where(party_id: p.id).find_each(&:destroy!) }
      Party.skip_cable_ready_updates { p.destroy! }
      dp += 1
    end
    LeagueTeam.where(league_id: league.id).find_each do |lt|
      LeagueTeam.skip_cable_ready_updates { lt.destroy! } # kaskadiert seedings + league_team_cc
      dlt += 1
    end
    League.skip_cable_ready_updates { league.destroy! }   # kaskadiert league_cc; nullify game_plan
    dl += 1
  end
  puts "  … #{i + 1}/#{bogus.size}" if ((i + 1) % 20).zero?
rescue => e
  puts "  FEHLER Liga[#{league.id}]: #{e.class} #{e.message[0, 120]}"
end
puts "FERTIG: #{dl} Ligen, #{dlt} LeagueTeams, #{dp} Parties geloescht (+ kaskadierte Seedings)."
