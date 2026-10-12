# frozen_string_literal: true

# Traegt die CC-seitigen IDs der ClubCloud-Turnierplaene nach.
#
# Hintergrund: Der Detail-Scrape (RegionCc::TournamentSyncer) liest nur den NAMEN des
# Turnierplans — die Meisterschafts-Detailseite fuehrt keine ID. TournamentPlanCc-Records
# entstehen dadurch per find_or_create_by(name:, context:) OHNE cc_id.
#
# Folge: TournamentPreparation::TournamentCloner konnte die echte tpid nicht kennen und sendete
# frueher den lokalen Fremdschluessel (bei NBV durchweg 1). Die ClubCloud verwarf die unbekannte
# ID stillschweigend — die Klon-Welle vom 10.07.2026 legte 36 NBV-Karambol-Turniere OHNE
# Turnierplan an, was in der CC nur durch Neuanlage des Turniers zu reparieren ist. Seit dem
# Guard in resolve_tpid bricht der Klon stattdessen ab, solange cc_id fehlt — dieser Task
# beseitigt die Ursache.
#
# Quelle der Werte: <select name="tpid"> der Meisterschafts-Anlagemaske (NBV, abgelesen
# 2026-09-05). CC: UNIVERSAL = 1000 deckt sich mit dem HAR-Wert aus Plan 50-02.
#
# Usage (auf carambus_api / Authority):
#   RAILS_ENV=production bundle exec rake tournament_plan_ccs:import_cc_ids DRY_RUN=true
#   RAILS_ENV=production bundle exec rake tournament_plan_ccs:import_cc_ids
#   RAILS_ENV=production bundle exec rake tournament_plan_ccs:import_cc_ids[bvnr]   # anderer Context
#
# Idempotent: Re-Runs aendern nichts. Ein bestehender Record mit ABWEICHENDER cc_id wird
# gemeldet und uebersprungen, nie ueberschrieben.
#
# Sicherheits-Mechanik:
# - Bewusst KEIN update_column: PaperTrail ist laut LocalProtector genau dann aktiv, wenn
#   carambus_api_url LEER ist — also auf der Authority. Ueber diese Versionen repliziert der
#   Sync die Records an die Local-Server. update_column wuerde die Version unterdruecken und
#   die cc_id nie bei nbv/bcw ankommen lassen, wo der Cloner sie braucht.
# - Live-Lauf auf einem Local-Server wird abgebrochen: TournamentPlanCc ist global
#   (id < MIN_ID), LocalProtector wuerde die Saves ohnehin zurueckrollen. DRY_RUN bleibt
#   ueberall erlaubt, um die Vorschau lokal pruefen zu koennen.

# [cc_id, name] — Namen EXAKT wie in der ClubCloud, der Scraper matcht ueber den Namen.
CC_TOURNAMENT_PLANS = [
  [1000, "CC: UNIVERSAL"],
  [108, "DKO-004"],
  [2001, "DKO-004 (Doppel-KO)"],
  [101, "DKO-008"],
  [2002, "DKO-008 (Doppel-KO)"],
  [2101, "DKO-008 + 4EKO (ab Halbfinale)"],
  [102, "DKO-016"],
  [2003, "DKO-016 (Doppel-KO)"],
  [3, "DKO-016 + 4EKO"],
  [2102, "DKO-016 + 4EKO (ab Halbfinale)"],
  [114, "DKO-016 + 4EKO + Spiel um Platz 3"],
  [105, "DKO-016 + 8EKO"],
  [2103, "DKO-016 + 8EKO (ab Viertelfinale)"],
  [103, "DKO-032"],
  [2004, "DKO-032 (Doppel-KO)"],
  [2106, "DKO-032 + 16EKO (ab Achtelfinale)"],
  [2104, "DKO-032 + 4EKO (ab Halbfinale)"],
  [104, "DKO-032 + 8EKO"],
  [2105, "DKO-032 + 8EKO (ab Viertelfinale)"],
  [107, "DKO-064"],
  [2005, "DKO-064 (Doppel-KO)"],
  [2108, "DKO-064 + 16EKO (ab Achtelfinale)"],
  [106, "DKO-064 + 8EKO"],
  [2107, "DKO-064 + 8EKO (ab Viertelfinale)"],
  [109, "DKO-128"],
  [2006, "DKO-128 (Doppel-KO)"],
  [2109, "DKO-128 + 16EKO (ab Achtelfinale)"],
  [2110, "DKO-128 + 32EKO (ab Letzte 32)"],
  [2007, "DKO-256 (Doppel-KO)"],
  [2111, "DKO-256 + 32EKO (ab Letzte 32)"],
  [2112, "DKO-256 + 64EKO (ab Letzte 64)"],
  [1001, "EKO-004 (Einfach-KO)"],
  [1002, "EKO-008 (Einfach-KO)"],
  [1003, "EKO-016 (Einfach-KO)"],
  [1004, "EKO-032 (Einfach-KO)"],
  [1005, "EKO-064 (Einfach-KO)"],
  [1006, "EKO-128 (Einfach-KO)"],
  [1007, "EKO-256 (Einfach-KO)"],
  [3000, "Gruppe A (jeder gegen jeden)"],
  [3001, "Gruppen (A-B) + Finale"],
  [3002, "Gruppen (A-D) + 4EKO (ab Halbfinale)"],
  [7001, "Gruppen (A-D) + DKO-08 + DKO-Trostrunde"],
  [3003, "Gruppen (A-H) + 8EKO (ab Viertelfinale)"],
  [7002, "Gruppen (A-H) + DKO-16 + DKO-Trostrunde"],
  [3004, "Gruppen (A-P) + 16EKO (ab Achtelfinale)"],
  [3005, "Gruppen (A-P) + 32EKO (ab letzte 32)"],
  [7003, "Gruppen (A-P) + DKO-32 + DKO-Trostrunde"],
  [201, "NBV: 8x4erGRP + 4x4erGRP + 8EKO (ab Viertelfinale)"],
  [5001, "Special: Kratzer-Turnier"],
  [6001, "Special: Schweizer System"],
  [4003, "TKO-016 (Trippel-KO)"]
].freeze

namespace :tournament_plan_ccs do
  desc "Traegt die CC-IDs der ClubCloud-Turnierplaene nach (DRY_RUN=true fuer Vorschau)"
  task :import_cc_ids, [:context] => :environment do |_task, args|
    context = (args[:context].presence || "nbv").downcase
    dry_run = ENV["DRY_RUN"] == "true"

    puts "=" * 78
    puts "TournamentPlanCc — CC-IDs nachtragen"
    puts "=" * 78
    puts "Context:  #{context}"
    puts "Mode:     #{dry_run ? "DRY-RUN (keine DB-Writes)" : "LIVE"}"
    puts "Quelle:   <select name=\"tpid\"> der Meisterschafts-Anlagemaske (NBV, 2026-09-05)"
    puts "Eintraege: #{CC_TOURNAMENT_PLANS.size}"
    puts ""

    if !dry_run && ApplicationRecord.local_server?
      abort "ABBRUCH: Dieser Server ist ein Local-Server (carambus_api_url gesetzt).\n" \
            "TournamentPlanCc ist ein globaler Record — LocalProtector wuerde jeden Save\n" \
            "zurueckrollen. Den Task auf der Authority (api.carambus.de) ausfuehren; die\n" \
            "Records kommen von dort per Sync zurueck.\n" \
            "Vorschau ist hier trotzdem moeglich: DRY_RUN=true"
    end

    created = []
    updated = []
    unchanged = []
    conflicts = []

    CC_TOURNAMENT_PLANS.each do |cc_id, name|
      record = TournamentPlanCc.find_or_initialize_by(name: name, context: context)

      if !record.persisted?
        created << [cc_id, name]
        next if dry_run
        record.cc_id = cc_id
        record.save!
      elsif record.cc_id == cc_id
        unchanged << [cc_id, name]
      elsif record.cc_id.present?
        conflicts << [record.cc_id, cc_id, name]
      else
        updated << [cc_id, name]
        next if dry_run
        record.update!(cc_id: cc_id)
      end
    end

    puts "Neu angelegt:  #{created.size}"
    puts "cc_id gesetzt: #{updated.size}"
    updated.each { |cc_id, name| puts "  #{cc_id.to_s.rjust(5)}  #{name}" }
    puts "Unveraendert:  #{unchanged.size}"

    if conflicts.any?
      puts ""
      puts "!! ABWEICHENDE cc_id — uebersprungen, nichts ueberschrieben:"
      conflicts.each { |old, neu, name| puts "  #{name}: DB=#{old} vs. CC=#{neu}" }
    end

    puts ""
    puts dry_run ? "DRY-RUN beendet — nichts geschrieben." : "Fertig."
    unless dry_run
      ohne = TournamentPlanCc.where(context: context, cc_id: nil).pluck(:name)
      puts "Ohne cc_id verbleiben: #{ohne.any? ? ohne.join(", ") : "keine"}"
    end
  end
end
