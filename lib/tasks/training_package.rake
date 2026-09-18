# frozen_string_literal: true

# Uebertragung globaler Trainingsvorlagen: Training Authority (carambus_train) -> Staging
# (Local Server) -> Authority (api.carambus.de), und zurueck. Entwurf: .paul/STATE.md,
# "Plan Schritt 3: Promotion-Werkzeug".
#
#   rake "training:package:export"                       # Paket nach tmp/training_packages/
#   PRUNE=1 rake "training:package:export"               # mit Loeschabsicht der Training Authority
#   rake "training:package:import[DATEI,staging]"        # Trockenlauf: zeigt nur, was passieren wuerde
#   APPLY=1 rake "training:package:import[DATEI,authority]"   # schreibt
#
# Rollen: staging (Local Server), authority (api.carambus.de), training_authority (carambus_train).
namespace :training do
  namespace :package do
    desc "Trainingspaket exportieren: training:package:export[DATEI] (PRUNE=1 haelt die Loeschabsicht fest)"
    task :export, %i[file] => :environment do |_t, args|
      package = TrainingPackage::Exporter.call(prune: ENV["PRUNE"] == "1")
      stamp = package["manifest"]["created_at"].delete("-:").sub(/\..*/, "")
      path = Pathname(args[:file].presence || Rails.root.join("tmp", "training_packages", "training_package_#{stamp}.json"))
      FileUtils.mkdir_p(path.dirname)
      File.write(path, JSON.pretty_generate(package))

      manifest = package["manifest"]
      puts "Paket geschrieben: #{path}"
      puts "  Quelle: #{manifest["source"]["basename"]} @ #{manifest["source"]["commit"].to_s.first(8)}, " \
           "Schema #{manifest["schema_version"]}, prune=#{manifest["prune"]}"
      puts "  SHA-256: #{manifest["sha256"]}"
      manifest["counts"].each { |table, n| puts format("  %-30s %5d", table, n) }
      skipped = manifest["skipped_local"].select { |_, n| n.positive? }
      puts "  nicht exportiert (lokale IDs >= MIN_ID): #{skipped.inspect}" if skipped.any?
    rescue TrainingPackage::Error => e
      abort "Export abgebrochen: #{e.message}"
    end

    desc "Trainingspaket importieren: training:package:import[DATEI,ROLLE] — Trockenlauf, APPLY=1 schreibt"
    task :import, %i[file role] => :environment do |_t, args|
      abort "Aufruf: rake \"training:package:import[DATEI,ROLLE]\"" if args[:file].blank? || args[:role].blank?

      package = JSON.parse(File.read(args[:file]))
      apply = ENV["APPLY"] == "1"
      report = TrainingPackage::Importer.call(package: package, role: args[:role], apply: apply)

      puts "#{apply ? "IMPORT" : "TROCKENLAUF"} #{args[:file]} als #{report.role} (prune=#{report.prune})"
      puts "  Tabelle                           neu  geändert  unverändert   nur im Ziel  gelöscht"
      report.tables.each do |table, c|
        puts format("  %-30s %6d %9d %12d %13d %9d",
          table, c[:new], c[:changed], c[:unchanged], c[:only_in_target].size, c[:deleted])
      end
      report.sequences.each { |table, (from, to)| puts "  Sequenz #{table}: #{from} -> #{to}" }

      orphans = report.tables.select { |_, c| c[:only_in_target].any? }
      if orphans.any? && !report.prune
        puts "  Nur im Ziel und ohne Löschabsicht im Paket — zur Training Authority zurückzuholen:"
        orphans.each { |table, c| puts "    #{table}: #{c[:only_in_target].first(20).inspect}" }
      end

      abort "Abgebrochen:\n  - #{report.errors.join("\n  - ")}" unless report.ok?
      puts apply ? "Geschrieben." : "Nichts geschrieben (Trockenlauf). Mit APPLY=1 anwenden."
    end
  end
end
