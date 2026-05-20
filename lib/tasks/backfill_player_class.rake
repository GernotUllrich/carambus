# frozen_string_literal: true

# Quick 260507-jfe Folgetask: Backfill Tournament#player_class fuer Bestandsdaten
#
# Hintergrund: quick-260507-jfe hat Tournament.parse_player_class_from_title +
# Wiring in Region#scrape_tournaments_data / Region#scrape_upcoming_tournaments
# eingefuehrt — neue Tournaments bekommen den Klassen-Wert automatisch.
# Bestandsdaten (~2000+ Records auf carambus_api production) bleiben jedoch
# nil bis dieser Task laeuft.
#
# Usage (auf carambus_api production):
#   RAILS_ENV=production bundle exec rake tournaments:backfill_player_class DRY_RUN=true
#   RAILS_ENV=production bundle exec rake tournaments:backfill_player_class
#
# Idempotent: Re-Runs aktualisieren nichts (Scope filtert player_class IS NULL).
#
# Sicherheits-Mechanik:
# - update_column umgeht Validations, Callbacks, PaperTrail und LocalProtector.
#   Backfill ist eine Daten-Korrektur, kein User-Edit — keine Versionierung gewollt.
# - PaperTrail ist auf carambus_api ohnehin nicht aktiviert (siehe LocalProtector:
#   has_paper_trail nur wenn carambus_api_url.present?), auf Local-Servern aktiv.
#   update_column umgeht die after_save-Trigger in beiden Faellen.
# - Restriction auf Parser-non-nil-Ergebnisse: kein nil-zu-nil-Update.

namespace :tournaments do
  desc "Backfill Tournament#player_class from title for existing records (DRY_RUN=true for preview)"
  task backfill_player_class: :environment do
    dry_run = ENV["DRY_RUN"] == "true"
    verbose = ENV["VERBOSE"] == "true"

    scope = Tournament.where(player_class: nil).where.not(title: [nil, ""])
    total = scope.count

    puts "=" * 70
    puts "Tournament#player_class backfill"
    puts "=" * 70
    puts "Mode:      #{dry_run ? 'DRY-RUN (no DB writes)' : 'LIVE'}"
    puts "Scope:     player_class IS NULL AND title present"
    puts "Candidates: #{total}"
    puts ""

    updated = 0
    no_match = 0
    distribution = Hash.new(0)
    samples = Hash.new { |h, k| h[k] = [] }

    scope.find_each.with_index do |t, i|
      parsed = Tournament.parse_player_class_from_title(t.title)
      if parsed.nil?
        no_match += 1
        next
      end

      distribution[parsed] += 1
      samples[parsed] << t.title if samples[parsed].size < 3

      if dry_run
        puts "  WOULD: ##{t.id.to_s.rjust(10)} #{parsed.inspect.ljust(7)} | #{t.title}" if verbose
      else
        t.update_column(:player_class, parsed)
      end
      updated += 1

      if ((i + 1) % 500).zero?
        puts "  ...scanned #{i + 1}/#{total}"
      end
    end

    puts ""
    puts "-" * 70
    puts "Summary"
    puts "-" * 70
    puts "Updated:   #{updated}#{dry_run ? ' (would update)' : ''}"
    puts "No match:  #{no_match} (no recognised class token in title)"
    puts ""
    puts "Distribution:"
    distribution.sort_by { |k, _v| Discipline::PLAYER_CLASS_ORDER.index(k) || 99 }.each do |klass, count|
      puts "  #{klass.ljust(5)} -> #{count.to_s.rjust(5)}   e.g. #{samples[klass].first}"
    end
    puts ""
    puts dry_run ? "DRY-RUN complete. Re-run without DRY_RUN=true to apply." : "Backfill complete."
  end
end
