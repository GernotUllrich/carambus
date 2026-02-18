# frozen_string_literal: true

namespace :videos do
  desc "Migrate international_videos from production to new videos table"
  task migrate_from_production: :environment do
    require 'pg'
    
    puts "\n" + "="*80
    puts "VIDEO MIGRATION: international_videos → videos"
    puts "="*80
    
    # Production DB connection
    prod_config = {
      host: ENV['PROD_DB_HOST'] || 'api.carambus.net',
      port: ENV['PROD_DB_PORT'] || 5432,
      dbname: 'carambus_api_production',
      user: ENV['PROD_DB_USER'] || 'www_data',
      password: ENV['PROD_DB_PASSWORD']
    }
    
    begin
      puts "\n1. Connecting to production database..."
      prod_conn = PG.connect(prod_config)
      puts "   ✓ Connected to #{prod_config[:host]}"
      
      # Check if source table exists
      result = prod_conn.exec("SELECT COUNT(*) FROM international_videos")
      total_videos = result[0]['count'].to_i
      puts "   ✓ Found #{total_videos} videos in production"
      
      if total_videos.zero?
        puts "\n   No videos to migrate. Exiting."
        prod_conn.close
        exit 0
      end
      
      puts "\n2. Fetching videos from production..."
      query = <<-SQL
        SELECT 
          id,
          external_id,
          title,
          description,
          thumbnail_url,
          duration,
          published_at,
          view_count,
          like_count,
          language,
          international_source_id,
          international_tournament_id,
          discipline_id,
          metadata,
          metadata_extracted,
          metadata_extracted_at,
          created_at,
          updated_at
        FROM international_videos
        ORDER BY id ASC
      SQL
      
      result = prod_conn.exec(query)
      puts "   ✓ Fetched #{result.ntuples} videos"
      
      puts "\n3. Migrating videos to new table..."
      migrated_count = 0
      skipped_count = 0
      error_count = 0
      
      result.each_with_index do |row, index|
        begin
          # Check if video already exists
          if Video.exists?(external_id: row['external_id'])
            skipped_count += 1
            next
          end
          
          # Map international_tournament_id to Tournament
          videoable_type = nil
          videoable_id = nil
          
          if row['international_tournament_id'].present?
            # Try to find InternationalTournament by old ID
            # Note: This assumes we have a mapping or we migrate tournaments first
            tournament = Tournament.find_by(id: row['international_tournament_id'])
            if tournament
              videoable_type = 'Tournament'
              videoable_id = tournament.id
            end
          end
          
          # Parse metadata (might be JSONB or JSON string)
          metadata = begin
            if row['metadata'].present?
              if row['metadata'].is_a?(String)
                JSON.parse(row['metadata'])
              else
                row['metadata']
              end
            else
              {}
            end
          rescue JSON::ParserError
            {}
          end
          
          # Create new Video
          Video.create!(
            external_id: row['external_id'],
            title: row['title'],
            description: row['description'],
            thumbnail_url: row['thumbnail_url'],
            duration: row['duration']&.to_i,
            published_at: row['published_at'],
            view_count: row['view_count']&.to_i,
            like_count: row['like_count']&.to_i,
            language: row['language'],
            international_source_id: row['international_source_id']&.to_i,
            videoable_type: videoable_type,
            videoable_id: videoable_id,
            discipline_id: row['discipline_id']&.to_i,
            data: metadata,
            metadata_extracted: row['metadata_extracted'] == 't',
            metadata_extracted_at: row['metadata_extracted_at'],
            created_at: row['created_at'],
            updated_at: row['updated_at']
          )
          
          migrated_count += 1
          
          # Progress indicator
          if (index + 1) % 100 == 0
            puts "   ... #{index + 1}/#{result.ntuples} processed (#{migrated_count} migrated, #{skipped_count} skipped)"
          end
          
        rescue StandardError => e
          error_count += 1
          puts "   ✗ Error migrating video #{row['external_id']}: #{e.message}"
          next
        end
      end
      
      puts "\n" + "="*80
      puts "MIGRATION COMPLETE"
      puts "="*80
      puts "Total videos in production: #{total_videos}"
      puts "Successfully migrated:      #{migrated_count}"
      puts "Skipped (already exists):   #{skipped_count}"
      puts "Errors:                     #{error_count}"
      puts "="*80
      
      # Show statistics
      puts "\n4. New Video Statistics:"
      puts "   Total videos:                #{Video.count}"
      puts "   Assigned to tournaments:     #{Video.for_tournaments.count}"
      puts "   Assigned to games:           #{Video.for_games.count}"
      puts "   Assigned to players:         #{Video.for_players.count}"
      puts "   Unassigned:                  #{Video.unassigned.count}"
      puts "   YouTube videos:              #{Video.youtube.count}"
      puts "   Metadata extracted:          #{Video.processed.count}"
      
      prod_conn.close
      
    rescue PG::Error => e
      puts "\n✗ Database Error: #{e.message}"
      puts "\nPlease ensure:"
      puts "1. You have network access to #{prod_config[:host]}"
      puts "2. Database credentials are correct (set PROD_DB_PASSWORD env var)"
      puts "3. PostgreSQL pg gem is installed"
      exit 1
    end
  end
  
  desc "Dry run - show what would be migrated"
  task dry_run: :environment do
    prod_config = {
      host: ENV['PROD_DB_HOST'] || 'api.carambus.net',
      port: ENV['PROD_DB_PORT'] || 5432,
      dbname: 'carambus_api_production',
      user: ENV['PROD_DB_USER'] || 'www_data',
      password: ENV['PROD_DB_PASSWORD']
    }
    
    begin
      prod_conn = PG.connect(prod_config)
      
      puts "\n" + "="*80
      puts "DRY RUN - Video Migration Preview"
      puts "="*80
      
      # Total count
      result = prod_conn.exec("SELECT COUNT(*) FROM international_videos")
      total = result[0]['count'].to_i
      puts "\nTotal videos in production: #{total}"
      
      # By assignment status
      result = prod_conn.exec(<<-SQL)
        SELECT 
          CASE 
            WHEN international_tournament_id IS NOT NULL THEN 'Assigned'
            ELSE 'Unassigned'
          END as status,
          COUNT(*) as count
        FROM international_videos
        GROUP BY status
      SQL
      
      puts "\nBy assignment status:"
      result.each { |row| puts "  #{row['status']}: #{row['count']}" }
      
      # By source
      result = prod_conn.exec(<<-SQL)
        SELECT 
          iss.name as source_name,
          COUNT(*) as count
        FROM international_videos iv
        JOIN international_sources iss ON iss.id = iv.international_source_id
        GROUP BY iss.name
        ORDER BY count DESC
        LIMIT 5
      SQL
      
      puts "\nTop 5 video sources:"
      result.each { |row| puts "  #{row['source_name']}: #{row['count']}" }
      
      # Sample unassigned videos
      result = prod_conn.exec(<<-SQL)
        SELECT external_id, title, published_at::date
        FROM international_videos
        WHERE international_tournament_id IS NULL
        ORDER BY published_at DESC
        LIMIT 5
      SQL
      
      puts "\nSample unassigned videos:"
      result.each do |row|
        puts "  [#{row['published_at']}] #{row['title']} (#{row['external_id']})"
      end
      
      puts "\n" + "="*80
      puts "Run 'rake videos:migrate_from_production' to perform migration"
      puts "Set PROD_DB_PASSWORD environment variable for authentication"
      puts "="*80
      
      prod_conn.close
      
    rescue PG::Error => e
      puts "\n✗ Connection Error: #{e.message}"
      exit 1
    end
  end
end
