# frozen_string_literal: true

namespace :season_participations do
  # Legt für jeden SeasonParticipation-Record der letzten Saison 2025/2026
  # einen äquivalenten Record in der Folgesaison 2026/2027 an.
  #
  # Alle neu erzeugten Records sind am gemeinsamen sync_date (heute 16:00)
  # erkennbar.
  #
  # Aufruf:
  #   bin/rails season_participations:copy_to_next_season
  #   bin/rails "season_participations:copy_to_next_season[2025/2026,2026/2027]"
  desc "Kopiert SeasonParticipations von 2025/2026 nach 2026/2027 (sync_date = heute 16:00)"
  task :copy_to_next_season, [:from, :to] => :environment do |_t, args|
    from_name = args[:from].presence || "2025/2026"
    to_name = args[:to].presence || "2026/2027"

    from_season = Season.find_by(name: from_name)
    to_season = Season.find_by(name: to_name)

    abort("Quell-Saison '#{from_name}' nicht gefunden") unless from_season
    abort("Ziel-Saison '#{to_name}' nicht gefunden") unless to_season

    sync_date = Time.zone.now.change(hour: 16, min: 0, sec: 0)

    created = 0
    skipped = 0

    puts "Kopiere SeasonParticipations #{from_name} (##{from_season.id}) -> #{to_name} (##{to_season.id})"
    puts "sync_date = #{sync_date}"

    from_season.season_participations.find_each do |sp|
      new_sp = SeasonParticipation.find_or_initialize_by(
        player_id: sp.player_id,
        club_id: sp.club_id,
        season_id: to_season.id
      )

      if new_sp.persisted?
        skipped += 1
        next
      end

      new_sp.status = sp.status
      new_sp.region_id = sp.region_id
      new_sp.ba_id = sp.ba_id
      new_sp.source_url = sp.source_url
      new_sp.data = sp.data
      new_sp.sync_date = sync_date
      new_sp.save!
      created += 1
    end

    puts "Fertig: #{created} neu angelegt, #{skipped} bereits vorhanden (übersprungen)."
  end
end
