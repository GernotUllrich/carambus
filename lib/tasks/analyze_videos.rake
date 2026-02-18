# frozen_string_literal: true

namespace :videos do
  desc "Analyze video content types and disciplines"
  task analyze: :environment do
    puts "\n" + "="*80
    puts "VIDEO CONTENT ANALYSIS"
    puts "="*80
    
    total = Video.count
    puts "\nTotal videos: #{total}"
    
    # 1. Discipline Detection
    puts "\n1. DISCIPLINE ANALYSIS"
    puts "-" * 80
    
    # Carom keywords
    carom_count = Video.where("title ILIKE ANY (ARRAY[?, ?, ?, ?, ?, ?])", 
                              '%3-cushion%', '%3 cushion%', '%dreiband%', 
                              '%carom%', '%world cup%', '%UMB%').count
    
    # Pool keywords  
    pool_count = Video.where("title ILIKE ANY (ARRAY[?, ?, ?, ?, ?])",
                             '%9-ball%', '%10-ball%', '%8-ball%', 
                             '%pool%', '%WPA%').count
    
    # Snooker keywords
    snooker_count = Video.where("title ILIKE ?", '%snooker%').count
    
    puts "Carom (3-Cushion) videos:    #{carom_count} (#{(carom_count.to_f / total * 100).round(1)}%)"
    puts "Pool (9/10/8-Ball) videos:   #{pool_count} (#{(pool_count.to_f / total * 100).round(1)}%)"
    puts "Snooker videos:              #{snooker_count} (#{(snooker_count.to_f / total * 100).round(1)}%)"
    puts "Unclassified:                #{total - carom_count - pool_count - snooker_count}"
    
    # 2. Content Type Detection
    puts "\n2. CONTENT TYPE ANALYSIS"
    puts "-" * 80
    
    # Full games (longer duration, has "vs" or match format)
    full_games = Video.where("duration > ? AND (title ILIKE ? OR title ILIKE ?)", 
                             1800, '%vs%', '%-%').count
    
    # Training/Shots (shorter, contains "shot", "drill", "training")
    training = Video.where("title ILIKE ANY (ARRAY[?, ?, ?, ?, ?])",
                          '%shot%', '%drill%', '%training%', '%practice%', '%bricol%').count
    
    # Highlights (contains "highlight", "best", "amazing")
    highlights = Video.where("title ILIKE ANY (ARRAY[?, ?, ?])",
                            '%highlight%', '%best%', '%amazing%').count
    
    # Tournament coverage (contains "final", "semi", "quarter", "round")
    tournament_matches = Video.where("title ILIKE ANY (ARRAY[?, ?, ?, ?])",
                                     '%final%', '%semi%', '%quarter%', '%round%').count
    
    puts "Full games (>30min):         #{full_games} (#{(full_games.to_f / total * 100).round(1)}%)"
    puts "Tournament matches:          #{tournament_matches} (#{(tournament_matches.to_f / total * 100).round(1)}%)"
    puts "Training/Shots:              #{training} (#{(training.to_f / total * 100).round(1)}%)"
    puts "Highlights:                  #{highlights} (#{(highlights.to_f / total * 100).round(1)}%)"
    
    # 3. Language Analysis
    puts "\n3. LANGUAGE DISTRIBUTION"
    puts "-" * 80
    
    languages = Video.group(:language).count.sort_by { |_, count| -count }.first(10)
    languages.each do |lang, count|
      lang_name = lang || 'unknown'
      puts "#{lang_name.ljust(15)} #{count.to_s.rjust(6)} (#{(count.to_f / total * 100).round(1)}%)"
    end
    
    # 4. Duration Analysis
    puts "\n4. DURATION ANALYSIS"
    puts "-" * 80
    
    with_duration = Video.where.not(duration: nil)
    avg_duration = with_duration.average(:duration).to_i
    max_duration = with_duration.maximum(:duration).to_i
    min_duration = with_duration.minimum(:duration).to_i
    
    puts "Videos with duration:        #{with_duration.count}"
    puts "Average duration:            #{avg_duration}s (#{(avg_duration / 60).round}min)"
    puts "Max duration:                #{max_duration}s (#{(max_duration / 60).round}min)"
    puts "Min duration:                #{min_duration}s"
    
    # Duration buckets
    shorts = Video.where("duration < ?", 300).count
    medium = Video.where("duration >= ? AND duration < ?", 300, 1800).count
    long = Video.where("duration >= ? AND duration < ?", 1800, 3600).count
    very_long = Video.where("duration >= ?", 3600).count
    
    puts "\nDuration buckets:"
    puts "  Shorts (<5min):            #{shorts}"
    puts "  Medium (5-30min):          #{medium}"
    puts "  Long (30-60min):           #{long}"
    puts "  Very long (>60min):        #{very_long}"
    
    # 5. Top Players in Titles
    puts "\n5. TOP PLAYERS MENTIONED IN TITLES"
    puts "-" * 80
    
    famous_players = [
      'JASPERS', 'SANCHEZ', 'ZANETTI', 'CAUDRON', 'MERCKX', 
      'CHO', 'HORN', 'BLOMDAHL', 'SAYGINER', 'TASDEMIR',
      'BAO PHƯƠNG', 'TRẦN', 'VAN BOENING', 'OUSCHAN'
    ]
    
    famous_players.each do |player|
      count = Video.where("title ILIKE ?", "%#{player}%").count
      puts "#{player.ljust(20)} #{count}" if count > 0
    end
    
    # 6. Video Sources Distribution
    puts "\n6. VIDEO SOURCES"
    puts "-" * 80
    
    sources = Video.joins(:international_source)
                   .group('international_sources.name')
                   .count
                   .sort_by { |_, count| -count }
    
    sources.each do |source, count|
      puts "#{source.ljust(30)} #{count.to_s.rjust(6)} (#{(count.to_f / total * 100).round(1)}%)"
    end
    
    # 7. View Statistics
    puts "\n7. ENGAGEMENT STATISTICS"
    puts "-" * 80
    
    total_views = Video.sum(:view_count)
    total_likes = Video.sum(:like_count)
    avg_views = Video.average(:view_count).to_i
    avg_likes = Video.average(:like_count).to_i
    
    puts "Total views:                 #{total_views.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "Total likes:                 #{total_likes.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "Average views per video:     #{avg_views}"
    puts "Average likes per video:     #{avg_likes}"
    puts "Average like rate:           #{((avg_likes.to_f / avg_views * 100).round(2))}%"
    
    # Top viewed videos
    puts "\nTop 10 most viewed videos:"
    Video.order(view_count: :desc).limit(10).each_with_index do |video, i|
      puts "#{(i+1).to_s.rjust(3)}. [#{video.view_count.to_s.rjust(8)} views] #{video.title[0..70]}"
    end
    
    puts "\n" + "="*80
  end
  
  desc "Tag videos with discipline based on content analysis"
  task tag_disciplines: :environment do
    puts "\n" + "="*80
    puts "AUTO-TAGGING DISCIPLINES"
    puts "="*80
    
    dreiband = Discipline.find_by("name ILIKE ?", "%dreiband%")
    
    if dreiband
      puts "\nTagging 3-Cushion/Dreiband videos..."
      
      carom_videos = Video.where("title ILIKE ANY (ARRAY[?, ?, ?, ?, ?, ?])", 
                                 '%3-cushion%', '%3 cushion%', '%dreiband%', 
                                 '%carom%', '%world cup%', '%UMB%')
                          .where(discipline_id: nil)
      
      count = carom_videos.update_all(discipline_id: dreiband.id)
      puts "✓ Tagged #{count} videos with Dreiband discipline"
    else
      puts "⚠ Dreiband discipline not found in database"
    end
    
    puts "\n" + "="*80
  end
  
  desc "Find potential full game videos for matching"
  task find_full_games: :environment do
    puts "\n" + "="*80
    puts "FINDING FULL GAME VIDEOS"
    puts "="*80
    
    # Criteria for full games:
    # 1. Duration > 20min
    # 2. Contains player names (vs, -, |)
    # 3. Not shorts/highlights/training
    # 4. Has metadata extracted
    
    potential_games = Video.where(metadata_extracted: true)
                           .where("duration > ?", 1200)
                           .where("title ILIKE ANY (ARRAY[?, ?, ?])", '%vs%', '%-%', '%|%')
                           .where("title NOT ILIKE ANY (ARRAY[?, ?, ?, ?])", 
                                  '%shot%', '%highlight%', '%short%', '%training%')
                           .order(published_at: :desc)
    
    puts "\nFound #{potential_games.count} potential full game videos"
    puts "\nSample (top 20):"
    puts "-" * 80
    
    potential_games.limit(20).each_with_index do |video, i|
      duration_min = (video.duration / 60).round
      puts "#{(i+1).to_s.rjust(3)}. [#{duration_min}min] #{video.title[0..80]}"
      puts "     YouTube: https://youtube.com/watch?v=#{video.external_id}"
      puts "     Published: #{video.published_at.strftime('%Y-%m-%d')}"
      puts ""
    end
    
    puts "="*80
    puts "These videos could be matched to games/tournaments via:"
    puts "1. Player name extraction from title"
    puts "2. Date matching with tournament dates"
    puts "3. Event name matching (World Cup, Championship, etc.)"
    puts "="*80
  end
end
