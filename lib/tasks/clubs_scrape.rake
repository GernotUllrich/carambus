# frozen_string_literal: true

# Vereins-Scrape (Region#scrape_clubs, inkl. Spieler) gezielt für eine Region statt im nächtlichen
# scrape:daily_update_monitored. Anlass: Nach der Umstellung auf cbdet/cbmemdet (7275dcfc) liest der erste
# Lauf jeden Verein vollständig (Roster-Fingerprints im alten Format) — so lässt er sich Region für
# Region vorziehen. Broadcast-frei; Änderungen erzeugen Versionen (Sync an die Server).
#
# Usage:
#   bundle exec rake clubs:scrape_region REGION=NBV                    # Spieler-Budget 800 Abrufe
#   bundle exec rake clubs:scrape_region REGION=NBV MAX_PLAYERS=300
#   bundle exec rake clubs:scrape_region REGION=NBV PLAYERS=false      # nur Vereinsdaten
# Vereine, für die das Budget nicht mehr reicht, werden ganz übersprungen und sind beim nächsten Lauf dran
# (Roster-Fingerprint bleibt stale). Wiederholen, bis „verschoben: 0“.
namespace :clubs do
  desc "Vereins-Scrape für eine Region (REGION=NBV, optional MAX_PLAYERS=800, PLAYERS=false)"
  task scrape_region: :environment do
    region = Region.find_by!(shortname: ENV.fetch("REGION"))
    season = Season.current_season
    players = ENV["PLAYERS"] != "false"
    max_players = ENV.fetch("MAX_PLAYERS", "800").to_i
    budget = {left: max_players, deferred: 0}
    count = lambda do
      clubs = Club.where(region_id: region.id)
      sp = SeasonParticipation.where(season: season, club_id: clubs.select(:id))
      {vereine: clubs.count, vereine_mit_dbu: clubs.where.not(dbu_nr: [nil, 0]).count, teilnahmen: sp.count,
       spieler_mit_dbu: Player.where(id: sp.select(:player_id)).where.not(dbu_nr: [nil, 0]).count,
       regionen: Region.count}
    end

    puts "Vereins-Scrape #{region.shortname} #{season.name} · Spieler: #{players} · Budget #{max_players} Spieler-Abrufe"
    before = count.call
    started = Time.current
    Club.skip_cable_ready_updates do
      Player.skip_cable_ready_updates do
        SeasonParticipation.skip_cable_ready_updates do
          region.scrape_clubs(season, from_background: true, player_details: players, player_budget: budget)
        end
      end
    end
    puts "Dauer: #{(Time.current - started).round} s · Spieler-Abrufe: #{max_players - budget[:left]} · " \
         "verschoben: #{budget[:deferred]} Vereine#{" → Task wiederholen" if budget[:deferred].positive?}"
    puts "vorher:  #{before}"
    puts "nachher: #{count.call}"
    puts "Abbruch oder Fehler: siehe log/production.log, Suche nach \"FATAL Error clubs_url\" bzw. \"Name Problem\""
  end
end
