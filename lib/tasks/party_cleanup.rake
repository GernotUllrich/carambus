# frozen_string_literal: true

# Plan 46.5-03: Phantom-Duplikat-Cleanup für Liga-Parties.
# Entfernt leere Dubletten (0 party_games + ergebnislos) je natürlichem Schlüssel; behält
# immer >= 1 Party je Termin, nie eine gespielte. Default DRY-RUN (löscht nichts).
#
#   rake party_cleanup:phantoms                      # Dry-Run, ganze DB (Report)
#   rake party_cleanup:phantoms LEAGUE_ID=9460       # Dry-Run, nur eine Liga
#   WRITE=true rake party_cleanup:phantoms           # FÜHRT AUS (nur auf der Authority)
#
# ⚠️ Reihenfolge: ZUERST Scraper-Idempotenz-Fix (46.5-02) deployen, DANN aufräumen — sonst
# legt der alte Scraper die Phantome neu an.
namespace :party_cleanup do
  desc "Phantom-Duplikat-Parties entfernen (Dedup je natürl. Schlüssel; DRY-RUN default, WRITE=true führt aus, LEAGUE_ID= grenzt ein)"
  task phantoms: :environment do
    dry_run = ENV["WRITE"] != "true"

    if !dry_run && ApplicationRecord.local_server?
      abort "ABBRUCH: Diese Maschine ist ein Local-Server (carambus_api_url gesetzt). " \
        "Global-Record-Deletes blockt LocalProtector — den Cleanup auf der AUTHORITY ausführen."
    end

    scope = if ENV["LEAGUE_ID"].present?
      League.find(ENV["LEAGUE_ID"]).parties
    else
      Party.all
    end

    prefix = dry_run ? "[DRY-RUN] " : ""
    puts "#{prefix}party_cleanup:phantoms — Scope: #{ENV["LEAGUE_ID"].present? ? "League #{ENV["LEAGUE_ID"]}" : "alle Ligen"}"

    report = Party.cleanup_phantom_duplicates(scope: scope, dry_run: dry_run)

    puts "#{prefix}Gruppen mit Dubletten: #{report[:groups_with_dupes]}"
    puts "#{prefix}#{dry_run ? "würde löschen" : "gelöscht"}: #{report[:deleted]} Parties"
    puts "#{prefix}behalten (kanonisch je Termin): #{report[:kept]}"
    ids_preview = report[:deleted_ids].first(10)
    puts "#{prefix}Beispiel-IDs: #{ids_preview.inspect}#{" …" if report[:deleted].to_i > ids_preview.size}"
    puts "→ Mit WRITE=true echtes Löschen ausführen (vorher diesen Dry-Run prüfen)." if dry_run
  end
end
