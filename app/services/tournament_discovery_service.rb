# frozen_string_literal: true

# Service to discover and create InternationalTournaments from video metadata
# Analyzes existing videos to identify tournaments and their details
class TournamentDiscoveryService
  attr_reader :discovered_tournaments, :videos_assigned

  def initialize
    @discovered_tournaments = []
    @videos_assigned = 0
  end

  # Discover tournaments from existing videos
  def discover_from_videos
    Rails.logger.info "[TournamentDiscovery] Starting tournament discovery from videos"
    
    # Get all tournament candidates from video metadata
    candidates = find_tournament_candidates
    
    Rails.logger.info "[TournamentDiscovery] Found #{candidates.size} tournament candidates"
    
    candidates.each do |candidate|
      tournament = find_or_create_tournament(candidate)
      if tournament
        @discovered_tournaments << tournament
        assign_videos_to_tournament(tournament, candidate)
      end
    end
    
    Rails.logger.info "[TournamentDiscovery] Created/updated #{@discovered_tournaments.size} tournaments"
    Rails.logger.info "[TournamentDiscovery] Assigned #{@videos_assigned} videos to tournaments"
    
    {
      tournaments: @discovered_tournaments,
      videos_assigned: @videos_assigned
    }
  end

  private

  # Find tournament candidates from video metadata
  def find_tournament_candidates
    candidates = []
    
    # Group videos by tournament_type + year + season
    InternationalVideo.where.not("metadata->>'tournament_type' IS NULL")
                     .where("metadata->>'year' > '0'")
                     .find_each do |video|
      
      tournament_type = video.metadata['tournament_type']
      year = video.metadata['year'].to_i
      season = video.metadata['season']
      
      # Create unique key for grouping
      key = [tournament_type, year, season].compact.join('_')
      
      # Find or create candidate
      candidate = candidates.find { |c| c[:key] == key }
      
      unless candidate
        candidate = {
          key: key,
          tournament_type: tournament_type,
          year: year,
          season: season,
          discipline: video.discipline,
          source: video.international_source,
          videos: []
        }
        candidates << candidate
      end
      
      candidate[:videos] << video
    end
    
    candidates
  end

  # Find or create tournament from candidate
  def find_or_create_tournament(candidate)
    # Build tournament name
    name = build_tournament_name(candidate)
    
    # Determine dates from videos
    videos = candidate[:videos]
    start_date = videos.map(&:published_at).compact.min
    end_date = videos.map(&:published_at).compact.max
    
    # Determine discipline (use most common from videos)
    discipline = determine_discipline(videos)
    
    unless discipline
      Rails.logger.warn "[TournamentDiscovery] No discipline found for #{name}, skipping"
      return nil
    end
    
    # Find or create tournament
    tournament = InternationalTournament.find_or_initialize_by(
      name: name,
      tournament_type: map_tournament_type(candidate[:tournament_type]),
      start_date: start_date
    )
    
    if tournament.new_record?
      tournament.assign_attributes(
        end_date: end_date,
        discipline: discipline,
        international_source: candidate[:source],
        data: {
          year: candidate[:year],
          season: candidate[:season],
          video_count: videos.size,
          auto_discovered: true,
          discovered_at: Time.current.iso8601
        }
      )
      
      if tournament.save
        Rails.logger.info "[TournamentDiscovery] Created tournament: #{name}"
      else
        Rails.logger.error "[TournamentDiscovery] Failed to create tournament #{name}: #{tournament.errors.full_messages}"
        return nil
      end
    else
      # Update existing tournament
      tournament.update(
        end_date: [tournament.end_date, end_date].compact.max,
        data: tournament.data.merge(
          video_count: videos.size,
          last_updated: Time.current.iso8601
        )
      )
      Rails.logger.info "[TournamentDiscovery] Updated tournament: #{name}"
    end
    
    tournament
  end

  # Build tournament name from candidate data
  def build_tournament_name(candidate)
    parts = [candidate[:tournament_type]]
    
    if candidate[:season].present?
      parts << candidate[:season]
    else
      parts << candidate[:year].to_s
    end
    
    parts.join(' ')
  end

  # Determine discipline from videos
  def determine_discipline(videos)
    # Count disciplines from videos that have one
    discipline_counts = videos.select { |v| v.discipline.present? }
                             .group_by(&:discipline)
                             .transform_values(&:count)
    
    return nil if discipline_counts.empty?
    
    # Return most common discipline
    discipline_counts.max_by { |_k, v| v }&.first
  end

  # Map tournament type strings to constants
  def map_tournament_type(type_string)
    case type_string.to_s.downcase
    when /world cup/i
      'world_cup'
    when /world championship/i
      'world_championship'
    when /european championship/i
      'european_championship'
    when /league/i
      'league'
    when /qualification/i
      'qualification'
    else
      'other'
    end
  end

  # Assign videos to tournament
  def assign_videos_to_tournament(tournament, candidate)
    candidate[:videos].each do |video|
      if video.international_tournament_id != tournament.id
        video.update(international_tournament_id: tournament.id)
        @videos_assigned += 1
      end
    end
  end
end
