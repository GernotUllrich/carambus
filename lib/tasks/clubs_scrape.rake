# frozen_string_literal: true

# Vereins-Scrape (Region#scrape_clubs, inkl. Spieler) gezielt für eine Region statt im nächtlichen
# scrape:daily_update_monitored. Anlass: Nach der Umstellung auf cbdet/cbmemdet (7275dcfc) liest der erste
# Lauf jeden Verein vollständig (Roster-Fingerprints im alten Format) — so lässt er sich Region für
# Region vorziehen. Broadcast-frei; Änderungen erzeugen Versionen (Sync an die Server).
#
# Usage:
#   bundle exec rake clubs:scrape_region REGION=NBV                    # POST-Budget 350
#   bundle exec rake clubs:scrape_region REGION=NBV MAX_POSTS=200
#   bundle exec rake clubs:scrape_region REGION=NBV PLAYERS=false      # nur Vereinsdaten
# Das Budget zählt JEDEN POST (Vereinsliste, Details, Mitgliederliste, Spieler, Wiederholungen) — die CC sperrt
# die IP nach ~400 POSTs, und das Fenster ist länger als 25 min: zwei Läufe hintereinander teilen sich das
# Kontingent (2026-11-26: BBBV ~185 + BVB ~195 → 429). Darum ein Lauf, dann Stunden warten.
# Vereine, für die das Budget nicht mehr reicht, werden ganz übersprungen und sind beim nächsten Lauf dran
# (Roster-Fingerprint bleibt stale). Wiederholen, bis „verschoben: 0“.
namespace :clubs do
  desc "Vereins-Scrape für eine Region (REGION=NBV, optional MAX_POSTS=350, PLAYERS=false)"
  task scrape_region: :environment do
    region = Region.find_by!(shortname: ENV.fetch("REGION"))
    season = Season.current_season
    players = ENV["PLAYERS"] != "false"
    abort "MAX_PLAYERS gibt es nicht mehr — MAX_POSTS zählt alle Anfragen (Standard 350)" if ENV["MAX_PLAYERS"]
    max_posts = ENV.fetch("MAX_POSTS", "350").to_i
    budget = {left: max_posts, deferred: 0}
    count = lambda do
      clubs = Club.where(region_id: region.id)
      sp = SeasonParticipation.where(season: season, club_id: clubs.select(:id))
      {vereine: clubs.count, vereine_mit_dbu: clubs.where.not(dbu_nr: [nil, 0]).count, teilnahmen: sp.count,
       spieler_mit_dbu: Player.where(id: sp.select(:player_id)).where.not(dbu_nr: [nil, 0]).count,
       regionen: Region.count}
    end

    puts "Vereins-Scrape #{region.shortname} #{season.name} · Spieler: #{players} · Budget #{max_posts} POSTs"
    before = count.call
    started = Time.current
    Club.skip_cable_ready_updates do
      Player.skip_cable_ready_updates do
        SeasonParticipation.skip_cable_ready_updates do
          region.scrape_clubs(season, from_background: true, player_details: players, post_budget: budget)
        end
      end
    end
    puts "Dauer: #{(Time.current - started).round} s · POSTs: #{max_posts - budget[:left]} · " \
         "verschoben: #{budget[:deferred]} Vereine#{" → Task wiederholen" if budget[:deferred].positive?}"
    puts "vorher:  #{before}"
    puts "nachher: #{count.call}"
    puts "Abbruch oder Fehler: siehe log/production.log, Suche nach \"FATAL Error clubs_url\" bzw. \"Name Problem\""
  end
end
