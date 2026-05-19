# frozen_string_literal: true

# Plan 14-G.14 Task 3: Bootstrap-Backfill für TournamentCc.registration_list_cc_id
#
# Setzt fehlende Verknüpfungen für historische Tournament/RegistrationList-Paare,
# bevor Regional-MCP-Server live über PATCH /api/tournament_ccs/.../registration_list_link
# pushen.
#
# Matching-Logik: Tournament.region_id + Tournament.title == RegistrationListCc.name
# in derselben Region (context = region.shortname.downcase). Idempotent über
# WHERE registration_list_cc_id IS NULL — zweiter Lauf macht 0 zusätzliche matches.
namespace :tournament_cc do
  desc "Backfill TournamentCc.registration_list_cc_id from name-match in same region"
  task backfill_registration_list_links: :environment do
    matched = 0
    skipped = 0
    errored = 0

    TournamentCc.where(registration_list_cc_id: nil).find_each do |tc|
      tournament = tc.tournament
      next unless tournament&.region_id

      region = tournament.region
      next unless region

      candidate = RegistrationListCc.find_by(
        context: region.shortname.downcase,
        name: tournament.title
      )

      if candidate
        # D-13-06.4-A Pattern (2. Anwendung): update_columns überspringt PaperTrail
        # für Backfill-Operationen (Daten-Befüllung; keine echten User-Changes)
        tc.update_columns(registration_list_cc_id: candidate.id)
        matched += 1
      else
        skipped += 1
      end
    rescue => e
      Rails.logger.error "[backfill] TournamentCc##{tc.id}: #{e.class}: #{e.message}"
      errored += 1
    end

    puts "Backfill complete: matched=#{matched} skipped=#{skipped} errored=#{errored}"
  end
end
