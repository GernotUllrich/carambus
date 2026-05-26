# frozen_string_literal: true

# Plan 21-06 T2 / Slice E: NBV-Pilot-Wrapper um RegionCc#sync_registration_list_ccs.
#
# Triggert den RegistrationSyncer (sync_registration_list_ccs + Detail-Calls je BranchCc)
# fuer eine Region+Saison. Designed fuer Cron (D-21-DISC-C + D-21-06-A): laeuft auf
# carambus_api (Authority), schreibt globale RegistrationListCc-Records (id < MIN_ID).
#
# Nutzt Setting.login_to_cc → PHPSESSID aus Setting; bei expired Session bailt der Syncer
# heute mid-flight ([[], "Sitzung ist ausgelaufen"]) — Recovery wie 21-03 with_session_recovery
# ist NICHT eingebaut (separater Defensivierungs-Slice falls 2h-Cron-Lauf das zeigt).
# Der naechste Cron-Lauf macht den Re-Login automatisch (Setting.login_to_cc oben).
#
# Saisonauflösung: explizit > Setting > Season.current_season (kalender-aware:
# (Date.today - 6.month).year → "YYYY/YYYY+1"; bei NBV heute 2026-05 → "2025/2026").
# FRÜHERE BUGGY-IMPL in 21-03 nutzte Season.order(name: :desc), die lexikalisch eine
# Future-Season-Stub wie "2028/2029" pickte → 0 Records. Lehre uebernommen.
#
# Beispiel:
#   bin/rails clubcloud:sync_meldelisten[NBV]
#   bin/rails clubcloud:sync_meldelisten[NBV,2025/2026]
#   bin/rails clubcloud:sync_meldelisten           # Default = NBV

namespace :clubcloud do
  desc "Sync RegistrationListCc records from ClubCloud (Plan 21-06 Slice E)"
  task :sync_meldelisten, [:region, :season] => :environment do |_t, args|
    region_abbr = (args[:region] || "NBV").upcase
    context = region_abbr.downcase

    region = Region.find_by(shortname: region_abbr)
    raise "Region #{region_abbr} not found" if region.nil?
    region_cc = region.region_cc
    raise "RegionCc for #{region_abbr} not found" if region_cc.nil?

    season_name = args[:season].presence ||
      Setting.key_get_value(:season_name).presence ||
      Season.current_season&.name
    raise "no season resolvable (pass :season explicitly)" if season_name.blank?

    season = Season.find_by(name: season_name)
    raise "Season '#{season_name}' not found" if season.nil?

    puts "[clubcloud:sync_meldelisten] region=#{region_abbr} season=#{season_name} context=#{context}"

    before_total = RegistrationListCc.where(context: context).count
    before_in_season = RegistrationListCc.where(context: context, season_id: season.id).count

    # PHPSESSID sicherstellen — fresh login wenn fehlend/expired.
    Setting.login_to_cc unless Setting.key_get_value("session_id").present?
    session_id = Setting.key_get_value("session_id")
    raise "ClubCloud login failed (no session_id in Setting)" if session_id.blank?

    # Sync auslösen (durchläuft alle BranchCc der Region intern).
    region_cc.sync_registration_list_ccs(
      context: context,
      season_name: season_name,
      session_id: session_id,
      update_from_cc: true
    )

    after_total = RegistrationListCc.where(context: context).count
    after_in_season = RegistrationListCc.where(context: context, season_id: season.id).count
    distinct_status = RegistrationListCc.where(context: context, season_id: season.id)
      .distinct.pluck(:status)

    puts "[clubcloud:sync_meldelisten] visited_total=#{before_total}->#{after_total} (delta=#{after_total - before_total})"
    puts "[clubcloud:sync_meldelisten] in_season_#{season_name}=#{before_in_season}->#{after_in_season} (delta=#{after_in_season - before_in_season})"
    puts "[clubcloud:sync_meldelisten] distinct_status_in_season=#{distinct_status.inspect}"
  end
end
