# frozen_string_literal: true

# Plan 21-03 T3 / Slice A: NBV-Pilot-Lauf des erweiterten TournamentSyncer.
#
# Scrape die 4 neuen Admin-Parameter (Shot-Clock-Schwellenwert, Ausspielziel,
# Best-of-Sätze, TurnierPlan) aus showMeisterschaft.php nach `tournament_ccs`.
# Modus `only_admin_params: true` lässt bestehende Felder (name/shortname/
# discipline/etc.) unangetastet — nur die 4 neuen Felder werden geschrieben.
#
# Bekannte Datenlage NBV (siehe `.paul/phases/21-clubcloud-admin-scraping/21-03-SNIFF-FINDINGS.md`):
# NBV pflegt diese Felder NICHT in ClubCloud-Admin → mehrheitlich NULL-Werte erwartet.
# Lauf dient (a) Infrastruktur-Validierung + (b) Future-Proofing für andere Regionen.
#
# Beispiel:
#   bin/rails clubcloud:scrape_admin_params[NBV]
#   bin/rails clubcloud:scrape_admin_params           # Default = NBV
#
namespace :clubcloud do
  desc "Scrape 4 admin params (shot_clock/points_to_win/best_of/plan) from showMeisterschaft.php into tournament_ccs (Plan 21-03 Slice A)"
  task :scrape_admin_params, [:region, :season] => :environment do |_t, args|
    region_abbr = (args[:region] || "NBV").upcase
    context = region_abbr.downcase

    region = Region.find_by(shortname: region_abbr)
    raise "Region #{region_abbr} not found" if region.nil?
    region_cc = region.region_cc
    raise "RegionCc for #{region_abbr} not found" if region_cc.nil?

    season_name = args[:season].presence || Setting.key_get_value(:season_name).presence ||
      Season.order(name: :desc).where("name ~ '^20[0-9]+/'").first&.name
    raise "no season resolvable (pass :season explicitly)" if season_name.blank?

    puts "[clubcloud:scrape_admin_params] region=#{region_abbr} season=#{season_name} context=#{context}"

    # Pre-Lauf-Counts (nur betreffende Region)
    base = TournamentCc.where(context: context, season: season_name)
    before = {
      total: base.count,
      shot_clock: base.where.not(shot_clock_minutes: nil).count,
      points_to_win: base.where.not(points_to_win: nil).count,
      best_of: base.where.not(best_of_sets: nil).count,
      plan: base.where.not(tournament_plan_cc_id: nil).count
    }
    plan_records_before = TournamentPlanCc.where(context: context).count
    puts "  before: total=#{before[:total]} shot_clock=#{before[:shot_clock]} " \
         "points_to_win=#{before[:points_to_win]} best_of=#{before[:best_of]} " \
         "plan=#{before[:plan]} plan_records=#{plan_records_before}"

    session_id = Setting.login_to_cc
    raise "ClubCloud login failed (no session_id)" if session_id.blank?
    client = region_cc.club_cloud_client

    RegionCc::TournamentSyncer.call(
      region_cc: region_cc, client: client,
      operation: :sync_tournament_ccs,
      context: context, season_name: season_name,
      update_from_cc: true,
      only_admin_params: true,
      session_id: session_id
    )

    # Post-Lauf-Counts
    base = TournamentCc.where(context: context, season: season_name)
    after = {
      total: base.count,
      shot_clock: base.where.not(shot_clock_minutes: nil).count,
      points_to_win: base.where.not(points_to_win: nil).count,
      best_of: base.where.not(best_of_sets: nil).count,
      plan: base.where.not(tournament_plan_cc_id: nil).count
    }
    plan_records_after = TournamentPlanCc.where(context: context).count
    puts "  after:  total=#{after[:total]} shot_clock=#{after[:shot_clock]} " \
         "points_to_win=#{after[:points_to_win]} best_of=#{after[:best_of]} " \
         "plan=#{after[:plan]} plan_records=#{plan_records_after}"

    delta = {
      shot_clock: after[:shot_clock] - before[:shot_clock],
      points_to_win: after[:points_to_win] - before[:points_to_win],
      best_of: after[:best_of] - before[:best_of],
      plan: after[:plan] - before[:plan],
      plan_records: plan_records_after - plan_records_before
    }
    puts format(
      "  delta:  shot_clock=%+d points_to_win=%+d best_of=%+d plan=%+d plan_records_created=%+d",
      delta[:shot_clock], delta[:points_to_win], delta[:best_of], delta[:plan], delta[:plan_records]
    )
  end
end
