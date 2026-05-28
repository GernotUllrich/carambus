# frozen_string_literal: true

# ============================================================================
# Plan 21-12: ClubCloud Tenant-URLs persistent für RegionCcs
# ============================================================================
# Hintergrund (2026-05-28): ClubCloud nutzt Tenant-spezifische Subdomains
# (32-char Hex). Die `base_url`-Spalte in `region_ccs` enthält den Tenant-Root,
# aus dem `Setting.login_to_cc` und alle showMeldelistenList/scrape-POSTs
# konstruiert werden.
#
# Symptom bei falscher/fehlender base_url:
#   - Setting.login_to_cc → "Login failed: Net::HTTPNotFound 404"
#   - Cron sync_meldelisten findet 0 Records in current_season
#   - Silent failure wenn alte session_id im Setting gespeichert ist
#     (login wird nicht erneuert, alle POSTs landen auf 404-Subdomain)
#
# Ausführen (Authority-Server / carambus_api):
#   RAILS_ENV=production bin/rails runner db/seeds/region_cc_base_urls.rb
#
# Idempotent: läuft beliebig oft, updated NUR wenn Wert abweicht. Nicht
# auto-loaded via db:seed (würde versehentlich überschreiben können).
# Bei Region-Tenant-URL-Änderungen: REGION_CC_BASE_URLS-Hash erweitern + Rerun.
# ============================================================================

REGION_CC_BASE_URLS = {
  "NBV" => "https://e12112e2454d41f1824088919da39bc0.club-cloud.de/",
  # Weitere Regionen hier ergänzen sobald die Tenant-URLs bekannt sind:
  # "BBBV" => "https://<32-char-hex>.club-cloud.de/",
  # "BVBW" => "https://<32-char-hex>.club-cloud.de/",
  # "BSV"  => "https://<32-char-hex>.club-cloud.de/",
}.freeze

puts "[Plan 21-12] Seed RegionCc.base_url — starting"
puts ""

updates = 0
already_correct = 0
skipped = 0

REGION_CC_BASE_URLS.each do |shortname, expected_url|
  region = Region.find_by(shortname: shortname)
  unless region
    puts "[SKIP]   #{shortname}: Region not in DB"
    skipped += 1
    next
  end

  rc = region.region_cc
  unless rc
    puts "[SKIP]   #{shortname}: RegionCc not in DB (region_id=#{region.id})"
    skipped += 1
    next
  end

  if rc.base_url == expected_url
    puts "[OK]     #{shortname}: base_url already correct"
    already_correct += 1
  else
    old = rc.base_url.inspect
    # update_column bypassed LocalProtector + paper_trail (DB-side-only update;
    # base_url ist Infrastruktur-Daten, kein Domain-State).
    rc.update_column(:base_url, expected_url)
    puts "[UPDATE] #{shortname}: #{old} → #{expected_url.inspect}"
    updates += 1
  end
end

puts ""
puts "[Plan 21-12] DONE — #{updates} updated, #{already_correct} already correct, #{skipped} skipped"
puts ""
puts "Hinweis: Falls Updates vorgenommen wurden, cached session löschen:"
puts "  Setting.key_set_value('session_id', nil)"
puts "  Setting.key_set_value('session_login_time', nil)"
puts "→ Nächster Cron-Lauf macht frischen Login auf der korrekten Subdomain."
