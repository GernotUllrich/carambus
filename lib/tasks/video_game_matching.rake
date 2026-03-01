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

      # Extrahiere IDs aus "player_-1234" oder suche nach Namen
      p1_id = player1.to_s.start_with?("player_") ? player1.to_s.split("_").last : nil
      p2_id = player2.to_s.start_with?("player_") ? player2.to_s.split("_").last : nil

      # Subqueries for players
      games_p1 = Game.joins(game_participations: :player)
                     .select(:id)
      games_p1 = if p1_id
                   games_p1.where(game_participations: { player_id: p1_id })
                 else
                   games_p1.where("players.fl_name ILIKE :p1 OR players.lastname ILIKE :p1", p1: "%#{player1}%")
                 end

      games_p2 = Game.joins(game_participations: :player)
                     .select(:id)
      games_p2 = if p2_id
                   games_p2.where(game_participations: { player_id: p2_id })
                 else
                   games_p2.where("players.fl_name ILIKE :p2 OR players.lastname ILIKE :p2", p2: "%#{player2}%")
                 end

      # Schnittmenge an Games bilden, in denen BEIDE vorkommen, und NUR InternationalTournaments
      possible_games = Game.joins(:tournament)
                           .where(id: games_p1)
                           .where(id: games_p2)
                           .where(tournaments: { type: "InternationalTournament" })

      # Optional: filtern nach Datum (ein Game sollte zum Turnier-Datum oder Video-Datum passen)
      if video.published_at.present? && possible_games.count > 1
        # Wir versuchen das Game auf +- 30 Tage vom published_at des Videos einzugrenzen
        possible_games = possible_games.where(
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
        puts "✓ Video [#{video.id}] '#{video.title.truncate(40)}' -> Game [#{game.id}] (Tournament: #{game.tournament.name})"
        success_count += 1
      else
        # Es gibt mehrere mögliche Matches (vielleicht spielen sie öfter gegeneinander).
        # Nehmen wir das aktuellste oder loggen es.
        game = possible_games.last
        video.update(videoable_type: "Game", videoable_id: game.id)
        puts "⚠ Mehrdeutig (#{possible_games.count} Matches) - ordne Video [#{video.id}] zu Game [#{game.id}] zu (Tournament: #{game.tournament.name})."
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
