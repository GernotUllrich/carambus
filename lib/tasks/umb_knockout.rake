# frozen_string_literal: true

namespace :umb do
  desc "Backfill K.-o.-Match-Games aus den Hauptrunden-PDFs (Quarter/Semi/Final) internationaler Turniere. " \
       "Optional: TOURNAMENT_ID=<id> für ein einzelnes Turnier."
  task backfill_knockout: :environment do
    scraper = Umb::DetailsScraper.new

    scope =
      if ENV["TOURNAMENT_ID"].present?
        Tournament.where(id: ENV["TOURNAMENT_ID"])
      else
        # Nur Turniere, die eine main_tournament-Phase (Quarter/Semi/Final) haben
        Tournament.international
          .joins(:games)
          .where("games.gname IN (?)", ["Quarter Final", "Semi Final & Final", "Semi Final", "Final"])
          .distinct
      end

    tournaments = scope.to_a
    puts "=== UMB Knockout-Backfill: #{tournaments.size} Turniere ==="

    total_games = 0
    tournaments.each do |t|
      created = scraper.backfill_knockout_results(t)
      total_games += created
      puts "  T##{t.id} #{t.date&.to_date} #{t.name.to_s.truncate(45)} -> #{created} K.-o.-Games" if created.positive?
    end

    puts "\n=== Fertig: #{total_games} K.-o.-Match-Games erzeugt/aktualisiert ==="
    puts "Hinweis: Danach 'rake umb:assign_tournament_videos_to_games' laufen lassen, damit QF/SF/Finale-Videos den neuen Games zugeordnet werden."
  end

  desc "Ordnet bereits TURNIER-zugeordnete Videos den einzelnen Games zu (per Spielernamen im selben Turnier). " \
       "Ergänzt videos:match_to_games (das nur komplett unzugeordnete Videos verarbeitet). " \
       "Optional: TOURNAMENT_ID=<id>."
  task assign_tournament_videos_to_games: :environment do
    scope = Video.where(videoable_type: "Tournament")
    scope = scope.where(videoable_id: ENV["TOURNAMENT_ID"]) if ENV["TOURNAMENT_ID"].present?

    assigned = 0
    ambiguous = 0
    no_match = 0

    scope.find_each do |video|
      tournament = Tournament.find_by(id: video.videoable_id)
      next unless tournament

      tags = (video.detect_player_tags || []).map { |x| x.to_s.downcase }.uniq
      next if tags.size < 2

      tag_a = tags[0]
      tag_b = tags[1]

      games = tournament.games.includes(game_participations: :player).to_a
      tournament_players = games.flat_map { |g| g.game_participations.map(&:player) }.compact.uniq

      # Präzisions-Guard: jeder Tag muss GENAU EINEN Spieler im Turnier eindeutig
      # identifizieren. Sonst (z.B. zwei "Kim") ist die Zuordnung unzuverlässig → skip.
      players_a = tournament_players.select { |p| p.fl_name.to_s.downcase.include?(tag_a) }
      players_b = tournament_players.select { |p| p.fl_name.to_s.downcase.include?(tag_b) }
      if players_a.map(&:id).uniq.size != 1 || players_b.map(&:id).uniq.size != 1
        ambiguous += 1
        next
      end

      # Game(s) mit exakt dieser Paarung
      candidates = games.select do |game|
        names = game.game_participations.map { |gp| gp.player&.fl_name.to_s.downcase }.compact
        next false unless names.size == 2

        (names[0].include?(tag_a) && names[1].include?(tag_b)) ||
          (names[0].include?(tag_b) && names[1].include?(tag_a))
      end

      # Nur bei EINDEUTIGKEIT zuordnen (Paarung kommt in genau einem Game vor)
      if candidates.size == 1
        video.update_columns(videoable_type: "Game", videoable_id: candidates.first.id)
        assigned += 1
      elsif candidates.empty?
        no_match += 1
      else
        ambiguous += 1
      end
    end

    puts "=== Turnier→Game-Video-Zuordnung ==="
    puts "Zugeordnet: #{assigned} | mehrdeutig übersprungen: #{ambiguous} | kein Game-Match: #{no_match}"
  end
end
