# frozen_string_literal: true

# Plan 21-06 T2 / Slice E + Plan 24-01 T1 (Phase-23-Nachzieher): NBV-Pilot-Wrapper
# um RegionCc#sync_registration_list_ccs.
#
# Triggert den RegistrationSyncer (sync_registration_list_ccs + Detail-Calls je BranchCc)
# fuer eine Region+Saison. Designed fuer Cron (D-21-DISC-C + D-21-06-A): laeuft auf
# carambus_api (Authority), schreibt seit Phase 23 T1b/T2 die meldeliste_*-Felder direkt
# auf TournamentCc (vorher RegistrationListCc — Tabelle/Modell wurden in Plan 23-01 T1b
# ersatzlos gedroppt).
#
# Plan 24-01 T1: Telemetrie-Counter umgestellt — vorher zählte das via RegistrationListCc,
# nach Phase 23 nicht mehr verfügbar. Nutzen jetzt TournamentCc.where.not(meldeliste_cc_id: nil)
# als Proxy für „synchronisierte Meldelisten". (status-Feld migrierte nicht — D-23-01-Spec —
# distinct_status-Telemetrie ist deshalb weggefallen.)
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
  desc "Sync meldeliste_* fields on TournamentCc from ClubCloud (Plan 21-06 Slice E + Plan 24-01 T1)"
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

    # Telemetrie-Proxy seit Phase 23: TCcs mit gesetztem meldeliste_cc_id =
    # bereits synchronisierte Meldelisten. Vorher via RegistrationListCc.count.
    before_total = TournamentCc.where(context: context).where.not(meldeliste_cc_id: nil).count
    before_in_season = TournamentCc.where(context: context, season: season_name).where.not(meldeliste_cc_id: nil).count

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

    after_total = TournamentCc.where(context: context).where.not(meldeliste_cc_id: nil).count
    after_in_season = TournamentCc.where(context: context, season: season_name).where.not(meldeliste_cc_id: nil).count

    puts "[clubcloud:sync_meldelisten] meldeliste_linked_total=#{before_total}->#{after_total} (delta=#{after_total - before_total})"
    puts "[clubcloud:sync_meldelisten] meldeliste_linked_in_season_#{season_name}=#{before_in_season}->#{after_in_season} (delta=#{after_in_season - before_in_season})"
  end
end
