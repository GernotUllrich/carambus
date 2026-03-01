# frozen_string_literal: true

namespace :videos do
  desc "Match unassigned videos to Games based on player names and dates (UMB / Cuesco / fivensix)"
  task match_to_games: :environment do
    puts "\n=== Matching unassigned Videos to Games ==="

    # Nur Videos betrachten, die noch keinem Objekt zugeordnet sind
    unassigned_videos = Video.where(videoable_id: nil)
    puts "Gefunden: #{unassigned_videos.count} nicht zugeordnete Videos"

    success_count = 0
    ambiguous_count = 0
    no_match_count = 0

    unassigned_videos.find_each do |video|
      # detect_player_tags analysiert den Titel nach Spielernamen
      detected_players = video.detect_player_tags

      # Wir brauchen mindestens 2 Spieler für ein Match
      if detected_players.size < 2
        no_match_count += 1
        next
      end

      player1 = detected_players[0]
      player2 = detected_players[1]

      # Finde Games, an denen beide erkannten Spieler teilnehmen
      # Game -> GameParticipation -> Player

      games_p1 = Game.joins(game_participations: :player)
                     .where("players.fl_name ILIKE :p1 OR players.lastname ILIKE :p1", p1: "%#{player1}%")
                     .select(:id)

      games_p2 = Game.joins(game_participations: :player)
                     .where("players.fl_name ILIKE :p2 OR players.lastname ILIKE :p2", p2: "%#{player2}%")
                     .select(:id)

      # Schnittmenge an Games bilden, in denen BEIDE vorkommen
      possible_games = Game.where(id: games_p1).where(id: games_p2)

      # Optional: filtern nach Datum (ein Game sollte zum Turnier-Datum oder Video-Datum passen)
      if video.published_at.present? && possible_games.count > 1
        # Wir versuchen das Game auf +- 30 Tage vom published_at des Videos einzugrenzen
        possible_games = possible_games.joins(:tournament).where(
          "tournaments.date >= ? AND tournaments.date <= ?",
          video.published_at - 30.days,
          video.published_at + 30.days
        )
      end

      case possible_games.count
      when 0
        no_match_count += 1
      when 1
        # Eindeutiger Treffer :)
        game = possible_games.first
        video.update(videoable_type: "Game", videoable_id: game.id)
        puts "✓ Video [#{video.id}] '#{video.title.truncate(40)}' -> Game [#{game.id}]"
        success_count += 1
      else
        # Es gibt mehrere mögliche Matches (vielleicht spielen sie öfter gegeneinander).
        # Nehmen wir das aktuellste oder loggen es.
        game = possible_games.last
        video.update(videoable_type: "Game", videoable_id: game.id)
        puts "⚠ Mehrdeutig (#{possible_games.count} Matches) - ordne Video [#{video.id}] zu Game [#{game.id}] zu."
        ambiguous_count += 1
        success_count += 1
      end
    end

    puts "\n=== Zusammenfassung ==="
    puts "Erfolgreich zugewiesen: #{success_count} (davon mehrdeutig: #{ambiguous_count})"
    puts "Kein Match gefunden:    #{no_match_count}"
    puts "=" * 40
  end
end
