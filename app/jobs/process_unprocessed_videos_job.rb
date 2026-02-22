# frozen_string_literal: true

# Background job to process unprocessed videos
# Extracts metadata, matches tournaments, assigns disciplines
class ProcessUnprocessedVideosJob < ApplicationJob
  queue_as :default

  def perform(limit: 50)
    Rails.logger.info "[ProcessUnprocessedVideosJob] Processing up to #{limit} unprocessed videos"

    unprocessed = Video.unprocessed.limit(limit)
    processed_count = 0

    unprocessed.each do |video|
      begin
        process_video(video)
        processed_count += 1
      rescue StandardError => e
        Rails.logger.error "[ProcessUnprocessedVideosJob] Error processing video #{video.id}: #{e.message}"
      end
    end

    Rails.logger.info "[ProcessUnprocessedVideosJob] Processed #{processed_count} videos"
    processed_count
  end

  private

  def process_video(video)
    # Auto-assign discipline if not yet assigned
    video.auto_assign_discipline! if video.discipline.blank?

    # Try to match tournament
    match_tournament(video)

    # Extract basic metadata
    metadata = extract_basic_metadata(video)

    # Mark as processed
    video.mark_processed!(metadata)
  end

  def match_tournament(video)
    # Try to find matching tournament by name and date
    return if video.published_at.blank?

    # Search in title for tournament names
    tournament_patterns = [
      /world cup/i,
      /world championship/i,
      /european championship/i,
      /WM|EM/i
    ]

    tournament_patterns.each do |pattern|
      next unless video.title.match?(pattern)

      # Look for tournaments around publication date (+/- 60 days)
      date_range = (video.published_at - 60.days)..(video.published_at + 60.days)

      matching_tournament = InternationalTournament
                           .where(discipline_id: video.discipline_id)
                           .where(start_date: date_range)
                           .where('name ILIKE ?', "%#{pattern.source.gsub(/[^\w\s]/, '')}%")
                           .first

      if matching_tournament
        video.update(international_tournament: matching_tournament)
        break
      end
    end
  end

  def extract_basic_metadata(video)
    metadata = {}

    # Extract year (check season format FIRST before single year)
    if match = video.title.match(/\b(20\d{2})\/(20\d{2})\b/)
      # For season format "2025/2026", use the second year
      metadata['year'] = match[2].to_i
      metadata['season'] = "#{match[1]}/#{match[2]}"
    elsif match = video.title.match(/\b(20\d{2})\b/)
      # Single year format
      metadata['year'] = match[1].to_i
    end

    # Extract round information
    round_patterns = {
      'Final' => /final/i,
      'Semi-Final' => /semi[- ]?final/i,
      'Quarter-Final' => /quarter[- ]?final/i,
      'Qualification' => /qualif/i
    }

    round_patterns.each do |round_name, pattern|
      if video.title.match?(pattern) || video.description.to_s.match?(pattern)
        metadata['round'] = round_name
        break
      end
    end

    # Extract player names (improved for international names)
    # Look for "Player1 vs Player2" or "Player1 - Player2"
    # Handles: "Eddy MERCKX vs Dick JASPERS" or "Glenn HOFMAN vs Marco ZANETTI"
    if match = video.title.match(/\b([A-Z][a-zéèêëàâäöüß]+(?:\s+[A-Z][A-ZÉÈÊËÀÂÄÖÜß]+)?)\s+(?:vs\.?|v\.?)\s+([A-Z][a-zéèêëàâäöüß]+(?:\s+[A-Z][A-ZÉÈÊËÀÂÄÖÜß]+)?)\b/)
      player1 = match[1].strip
      player2 = match[2].strip
      metadata['players'] = [player1, player2]
      metadata['match'] = "#{player1} vs #{player2}"
    end

    # Extract league/tournament info
    if match = video.title.match(/(Kozoom League|French League|World Cup|World Championship)/i)
      metadata['tournament_type'] = match[1]
    end

    # Extract round info if present
    if match = video.title.match(/Round\s+(\d+)/i)
      metadata['round_number'] = match[1].to_i
    end

    metadata
  end
end
