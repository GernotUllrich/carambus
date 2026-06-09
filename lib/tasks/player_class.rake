# frozen_string_literal: true

# Plan 21-01 T2 (v0.6 Phase 21): Rake-Trigger fuer PlayerClassCalculator.
# Berechnet PlayerRanking.player_class_id aus max(btg) der 2 Vorsaisons je
# Spieler/Disziplin/Region und persistiert das Ergebnis.
#
# Usage:
#   rake "player_class:calculate"                  # alle Regionen + alle Karambol-Disziplinen
#   rake "player_class:calculate[NBV]"             # nur NBV
#   DRY=1 rake "player_class:calculate[NBV]"       # dry-run (nichts schreiben, nur zaehlen)
#
# zsh: Argumente in Anfuehrungszeichen setzen (Glob).
namespace :player_class do
  desc "Berechnet PlayerRanking.player_class_id aus max(btg) der 2 abgeschlossenen Vorsaisons (STO-BTK §1.4). Args: [REGION_SHORTNAME] (optional). ENV: DRY=1 fuer dry-run."
  task :calculate, [:region_shortname] => :environment do |_t, args|
    region = nil
    if args[:region_shortname].present?
      shortname = args[:region_shortname].to_s.upcase
      region = Region.find_by(shortname: shortname)
      if region.nil?
        warn "Region '#{shortname}' nicht gefunden."
        exit 1
      end
    end

    dry_run = ENV["DRY"].present?
    label = dry_run ? "DRY-RUN" : "LIVE"
    scope = region ? "region=#{region.shortname}" : "region=ALL"
    puts "[player_class:calculate #{label}] #{scope}"
    result = PlayerClassCalculator.call(region: region, dry_run: dry_run)
    puts "[player_class:calculate #{label}] #{result.inspect}"
  end
end
