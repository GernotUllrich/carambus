# frozen_string_literal: true

# Whenever schedule configuration
# Learn more: https://github.com/javan/whenever
#
# Deploy with: whenever --update-crontab
# Clear with: whenever --clear-crontab
# View cron: crontab -l

# Capistrano passes variables via the `--set` option (see config/deploy.rb).
# We provide fallback defaults for local execution without Capistrano.
@environment  ||= ENV.fetch("RAILS_ENV", "production")
@path         ||= "/var/www/carambus_api/current"
@scenarioname ||= "carambus_api"
@location_id  ||= "1"

# Plan 21-08 (Region-Generalisierung): aktive Regionen für Phase-21-Cluster-Cron-Jobs.
# ENV-driven Operations-Konfig (D-21-08-A/B); Default = NBV → kein Verhaltens-Change
# bei Deploy ohne neuen Setup. Hebt D-21-06-D (NBV-Pilot) auf.
# Setzen via systemd Environment="ACTIVE_SCRAPE_REGIONS=NBV,BBBV,BVBW" oder ENV-Var.
# Whitespace + Case werden normalisiert.
@active_scrape_regions ||= ENV.fetch("ACTIVE_SCRAPE_REGIONS", "NBV")
                              .split(",")
                              .map { |r| r.strip.upcase }
                              .reject(&:empty?)
                              .freeze

set :output, "log/cron.log"
set :environment, @environment
set :path, @path

# Use absolute paths for commands with proper rbenv
job_type :rake, "cd :path && RAILS_ENV=:environment /var/www/.rbenv/shims/bundle exec rake :task :output"
job_type :runner,
         "cd :path && RAILS_ENV=:environment /var/www/.rbenv/shims/bundle exec rails runner -e :environment ':task' :output"

# ============================================================================
# INTERNATIONAL CONTENT SCRAPING
# ============================================================================

# Daily YouTube scraping + auto-tagging + processing
# Runs at 2:00 AM every day
# - Scrapes all 19 YouTube channels (last 3 days)
# - Auto-tags videos (players, content type, quality)
# - Discovers tournaments
# - Translates titles (if configured)
every 1.day, at: "2:00 am", roles: [:api] do
  rake "international:daily_scrape"
end

# Daily UMB tournament data scraping & maintenance
# Runs at 3:00 AM every day
# - Scrapes future tournaments
# - Finds new tournament IDs
# - Auto-fixes missing organizers (ensures all have UMB as organizer)
# - Updates recent tournaments with results
every 1.day, at: "3:00 am", roles: [:api] do
  rake "umb:update"
end

# Daily Cuesco (Five&Six) tournament and live results scraping
# Runs at 4:00 AM every day
# - Syncs recent/active tournaments from cuesco.net
# - Resolves game participations and maps to videos
every 1.day, at: "4:00 am", roles: [:api] do
  rake "cuesco:scrape_live"
end

# Weekly cleanup: Process all remaining untagged videos
# Runs every Sunday at 5:00 AM (after daily_update at 4am)
# - Ensures no videos are left unprocessed
# - Catches any videos that were skipped during daily runs
every :sunday, at: "5:00 am", roles: [:api] do
  rake "international:process_untagged_videos"
end

# ============================================================================
# REGIONAL/LOCAL SCRAPING (if enabled)
# ============================================================================

# Uncomment if you want to sync regional ClubCloud data daily
# ⚠️ DEFERRED (D-21-06-F): bleibt auskommentiert wegen Season[16]-Hardcode-Bug in
# der Implementierung (siehe lib/tasks/scrape.rake — sollte Season.current_season
# nutzen statt Season[16]). Eigener Fix-Slice im Phase-21-Cluster-Backlog.
# every 1.day, at: '5:00 am' do
#   rake "scrape:optimized_daily_update"
# end

# ============================================================================
# PHASE 21 CLUBCLOUD-ADMIN-SCRAPING (Plan 21-06 Slice E + 21-08 Region-Generalisierung)
# ============================================================================
# Cron-Verdrahtung der Phase-21-Cluster-Operations. Alle Jobs laufen mit
# roles: [:api] = NUR auf carambus_api (Authority-only Sub-Property von :app,
# D-21-10-G; D-21-06-A überholt durch 21-10 Role-Semantik-Fix); carambus_gu
# pullt Daten via existierendem Sync-Layer ([[project_clubcloud_scraping_authority_only]]).
#
# Multi-Region (D-21-08-A/B): aktive Regionen aus @active_scrape_regions oben (Default
# ["NBV"], via ENV ACTIVE_SCRAPE_REGIONS=NBV,BBBV,... erweiterbar).
# Hebt D-21-06-D (NBV-Pilot) auf — Phase-21-Cluster-Cron ist nicht mehr NBV-only by design.
# Aktivierung weiterer Regionen: systemd Environment="ACTIVE_SCRAPE_REGIONS=NBV,BBBV,BVBW"
# + cap production deploy (cron-update via cap-Whenever-Hook).
#
# Frequency-Staffelung (D-21-06-B / D-21-08-D): alle Regionen einer Operation teilen
# denselben Zeitslot (sequentielle Cron-Lines, kein Per-Region-Offset).
#
# Per-Operation-Doku:
# - Meldeliste-Sync 2h: zeit-sensitiv (Status/Deadline/Qualifying-Date wechseln
#   stuendlich kurz vor Meldeschluss). Quelle: ExternalTournament-App liest dies via
#   Endpoint 16 (Plan 21-05). Plan 21-06 T2 (Rake-Wrapper) + 21-06 T1 (Status-Bug-Fix).
# - TournamentCc-Admin-Parameter 04:30: Shot-Clock, points_to_win, best_of_sets,
#   tournament_plan_cc_id. Plan 21-03 Slice A.
# - PlayerRanking.player_class_id 05:30: PlayerClassCalculator (max GD aus 2 abgeschl.
#   Vorsaisons, STO-BTK §1.4). Plan 21-01.
# - Player age_class + gender 06:30: PlayerAgeClassGenderHeuristic (MAX(category_cc.min_age)
#   + juengste seedings.sex). Plan 21-04 Slice C.

@active_scrape_regions.each do |region|
  every 2.hours, roles: [:api] do
    rake "clubcloud:sync_meldelisten[#{region}]"
  end

  every 1.day, at: "4:30 am", roles: [:api] do
    rake "clubcloud:scrape_admin_params[#{region}]"
  end

  every 1.day, at: "5:30 am", roles: [:api] do
    rake "player_class:calculate[#{region}]"
  end

  every 1.day, at: "6:30 am", roles: [:api] do
    rake "players:heuristic_age_class_gender[#{region}]"
  end
end

# ============================================================================
# MAINTENANCE TASKS
# ============================================================================

# Weekly: Clean up old logs (keep last 90 days)
# Runs every Sunday at 6:00 AM
every :sunday, at: "6:00 am", roles: [:api] do
  rake "scrape:cleanup_logs[90]"
end

# Monthly: Update video statistics and tag counts
# Runs on the 1st of each month at 7:00 AM
every "0 7 1 * *", roles: [:api] do
  rake "international:update_statistics"
end

# ============================================================================
# LOCAL SERVER TASKS
# ============================================================================

# Every hour, or any desired interval for local sync tasks
every 1.hour, roles: [:local] do
  # Updates local data from the central API server.
  # the scenario and location are passed via Capistrano variables.
  rake "carambus:retrieve_updates[#{@location_id}]"
end

# Plan 17-05 (Vision N): Mitternachts-Auto-Abbruch für App-getriebene lokale Turniere.
# Safety-Net: gibt über Nacht hängende Tischbindungen lokaler App-Turniere
# (id>=MIN_ID + manual_assignment) frei. Idempotent.
every 1.day, at: "12:01 am", roles: [:local] do
  rake "external_tournament:release_stale_local_tables"
end

# ============================================================================
# NOTES
# ============================================================================
#
# After editing this file, deploy to cron with:
#   whenever --update-crontab --set environment=production
#
# To see what will be generated:
#   whenever
#
# To clear all whenever jobs:
#   whenever --clear-crontab
#
# View current crontab:
#   crontab -l
