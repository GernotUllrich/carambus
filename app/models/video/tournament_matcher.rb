# frozen_string_literal: true

require "text"

# ApplicationService for confidence-scored video-to-tournament matching.
#
# Scores each unassigned Video against InternationalTournament records using
# three weighted signals:
#   - Date overlap    (0.40): video.published_at within tournament date range (+3 day grace)
#   - Player intersection (0.35): Anteil der im Video erkannten Spieler, die im
#     Turnier antreten (Containment — NICHT Jaccard, siehe player_intersection_score)
#   - Title similarity (0.25): normalized Levenshtein distance
#
# Auto-assigns videos scoring >= CONFIDENCE_THRESHOLD (0.75). D-02: no review
# tier implemented — auto-assign only.
#
# Usage:
#   Video::TournamentMatcher.call
#   Video::TournamentMatcher.call(video_scope: Video.where(id: [1,2,3]))
class Video::TournamentMatcher < ApplicationService
  CONFIDENCE_THRESHOLD = 0.75
  DATE_WEIGHT = 0.40
  PLAYER_WEIGHT = 0.35
  TITLE_WEIGHT = 0.25

  def initialize(kwargs = {})
    @video_scope = kwargs[:video_scope] || Video.unassigned
    @results = []
  end

  def call
    assigned = 0
    skipped = 0

    tournaments = InternationalTournament.where("date >= ?", 2.years.ago).includes(seedings: :player)

    @video_scope.find_each do |video|
      # Skip already-assigned videos (videoable_id set)
      if video.videoable_id.present?
        skipped += 1
        next
      end

      extractor = Video::MetadataExtractor.new(video)
      metadata = extractor.extract_all

      best_tournament = nil
      best_score = 0.0

      tournaments.each do |tournament|
        score = confidence_score(video, tournament, metadata)
        if score > best_score
          best_score = score
          best_tournament = tournament
        end
      end

      if best_score >= CONFIDENCE_THRESHOLD && best_tournament
        video.update(videoable: best_tournament)
        assigned += 1
        @results << {video_id: video.id, tournament_id: best_tournament.id, confidence: best_score}
      else
        skipped += 1
      end
    end

    {assigned_count: assigned, skipped_count: skipped, results: @results}
  end

  # Public so tests can call it directly.
  def confidence_score(video, tournament, metadata = nil)
    metadata ||= Video::MetadataExtractor.new(video).extract_all
    score = 0.0
    score += date_overlap_score(video, tournament) * DATE_WEIGHT
    score += player_intersection_score(metadata[:players], tournament) * PLAYER_WEIGHT
    score += title_similarity_score(video.title, tournament.title) * TITLE_WEIGHT
    score.clamp(0.0, 1.0)
  end

  private

  # Returns 1.0 if video.published_at falls within the tournament date range
  # (with a +3 day grace period after end_date). Falls back to date + 7 days
  # when end_date is nil (D-06 from context: nil end_date fallback).
  def date_overlap_score(video, tournament)
    return 0.0 if video.published_at.blank? || tournament.date.blank?

    end_date = tournament.end_date || (tournament.date + 7.days)
    range = tournament.date.to_date..(end_date.to_date + 3.days)
    range.cover?(video.published_at.to_date) ? 1.0 : 0.0
  end

  # Anteil der im Video erkannten Spieler, die im Turnier antreten (Containment).
  #
  # Frueher Jaccard (Schnitt/Vereinigung) — das war fuer diesen Zweck die falsche
  # Metrik: ein Video zeigt zwei bis drei Spieler, ein World-Cup-Feld hat bis zu
  # 300. Die Vereinigung wird also von der Turniergroesse dominiert, und der Wert
  # sinkt, je vollstaendiger die Teilnehmerdaten sind — ausgerechnet gute Daten
  # wurden bestraft.
  #
  # Rechnerisch war die Schwelle von 0.75 damit unerreichbar: bei zwei erkannten
  # Spielern haette das Turnier hoechstens zwei bis drei Tags haben duerfen.
  # Gemessen am World Cup 2024 (292 Seedings, 80 Videos im Zeitfenster): bester
  # Score 0.48, keine einzige Zuordnung. Mit Containment: 20 Zuordnungen, bester
  # Score 0.80 — ein Video mit "D. JASPERS vs M. ABDIN" trifft jetzt 1.0, weil
  # Jaspers tatsaechlich im Feld steht.
  #
  # Bezugsgroesse ist bewusst die VIDEO-Seite: gefragt ist "spielen die gezeigten
  # Spieler in diesem Turnier?", nicht "wie gross ist die Ueberlappung beider
  # Mengen?".
  def player_intersection_score(detected_tags, tournament)
    return 0.0 if detected_tags.blank?

    seeded_tags = tournament_player_tags(tournament)
    return 0.0 if seeded_tags.empty?

    detected = detected_tags.uniq
    (detected & seeded_tags).size.to_f / detected.size
  end

  # Maps tournament seedings to lowercase WORLD_CUP_TOP_32 tag keys.
  def tournament_player_tags(tournament)
    tournament.seedings.map do |seeding|
      lastname = seeding.player&.lastname&.upcase
      next unless lastname

      InternationalHelper::WORLD_CUP_TOP_32.keys.find { |tag| lastname.include?(tag) }
    end.compact.map(&:downcase)
  end

  # Normalized Levenshtein similarity: 1.0 - (distance / max_length).
  def title_similarity_score(str1, str2)
    return 0.0 if str1.blank? || str2.blank?

    s1 = str1.to_s.downcase.strip
    s2 = str2.to_s.downcase.strip
    return 1.0 if s1 == s2

    max_length = [s1.length, s2.length].max
    return 0.0 if max_length == 0

    distance = Text::Levenshtein.distance(s1, s2)
    1.0 - (distance.to_f / max_length)
  end
end
