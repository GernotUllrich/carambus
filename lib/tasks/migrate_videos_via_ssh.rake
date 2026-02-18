# frozen_string_literal: true

namespace :videos do
  desc "Migrate videos from production via SSH + psql dump"
  task migrate_via_ssh: :environment do
    puts "\n" + "="*80
    puts "VIDEO MIGRATION VIA SSH"
    puts "="*80
    
    # 1. Export from production via SSH
    puts "\n1. Exporting videos from production..."
    export_file = Rails.root.join('tmp', 'production_videos.json')
    
    export_sql = <<-SQL
      SELECT json_agg(row_to_json(t)) 
      FROM (
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
      ) t;
    SQL
    
    cmd = "ssh api \"sudo -u postgres psql -d carambus_api_production -t -c \\\"#{export_sql.gsub('"', '\\"')}\\\"\""
    result = `#{cmd}`
    
    if $?.success?
      File.write(export_file, result.strip)
      puts "   ✓ Exported to #{export_file}"
    else
      puts "   ✗ Export failed!"
      exit 1
    end
    
    # 2. Parse JSON
    puts "\n2. Parsing exported data..."
    data = JSON.parse(File.read(export_file))
    puts "   ✓ Found #{data.size} videos"
    
    # 3. Import into local database
    puts "\n3. Importing videos..."
    migrated = 0
    skipped = 0
    errors = 0
    
    data.each_with_index do |row, index|
      begin
        # Check if exists
        if Video.exists?(external_id: row['external_id'])
          skipped += 1
          next
        end
        
        # Map tournament
        videoable_type = nil
        videoable_id = nil
        
        if row['international_tournament_id'].present?
          tournament = Tournament.find_by(id: row['international_tournament_id'])
          if tournament
            videoable_type = 'Tournament'
            videoable_id = tournament.id
          end
        end
        
        # Parse metadata
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
        
        # Create video
        Video.create!(
          external_id: row['external_id'],
          title: row['title'],
          description: row['description'],
          thumbnail_url: row['thumbnail_url'],
          duration: row['duration'],
          published_at: row['published_at'],
          view_count: row['view_count'],
          like_count: row['like_count'],
          language: row['language'],
          international_source_id: row['international_source_id'],
          videoable_type: videoable_type,
          videoable_id: videoable_id,
          discipline_id: row['discipline_id'],
          data: metadata,
          metadata_extracted: row['metadata_extracted'],
          metadata_extracted_at: row['metadata_extracted_at'],
          created_at: row['created_at'],
          updated_at: row['updated_at']
        )
        
        migrated += 1
        
        if (index + 1) % 100 == 0
          puts "   ... #{index + 1}/#{data.size} (#{migrated} migrated, #{skipped} skipped)"
        end
        
      rescue StandardError => e
        errors += 1
        puts "   ✗ Error: #{row['external_id']}: #{e.message}"
      end
    end
    
    puts "\n" + "="*80
    puts "MIGRATION COMPLETE"
    puts "="*80
    puts "Total in production:        #{data.size}"
    puts "Successfully migrated:      #{migrated}"
    puts "Skipped (already exists):   #{skipped}"
    puts "Errors:                     #{errors}"
    puts "="*80
    
    # Statistics
    puts "\n4. Video Statistics:"
    puts "   Total:                   #{Video.count}"
    puts "   Assigned to tournaments: #{Video.for_tournaments.count}"
    puts "   Unassigned:              #{Video.unassigned.count}"
    puts "   YouTube:                 #{Video.youtube.count rescue 0}"
    puts "   Metadata extracted:      #{Video.processed.count}"
    
    # Cleanup
    File.delete(export_file)
    puts "\n✓ Cleaned up temporary file"
  end
  
  desc "Preview migration (dry run)"
  task preview: :environment do
    puts "\n" + "="*80
    puts "VIDEO MIGRATION PREVIEW"
    puts "="*80
    
    # Get stats via SSH
    puts "\n1. Fetching statistics from production..."
    
    stats_sql = <<-SQL
      SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE international_tournament_id IS NOT NULL) as assigned,
        COUNT(*) FILTER (WHERE international_tournament_id IS NULL) as unassigned,
        COUNT(*) FILTER (WHERE metadata_extracted = true) as extracted,
        MIN(published_at)::date as earliest,
        MAX(published_at)::date as latest
      FROM international_videos;
    SQL
    
    result = `ssh api "sudo -u postgres psql -d carambus_api_production -t -c \\"#{stats_sql}\\""`
    puts result
    
    # Sample videos
    puts "\n2. Sample assigned videos:"
    sample_sql = <<-SQL
      SELECT external_id, title, published_at::date
      FROM international_videos
      WHERE international_tournament_id IS NOT NULL
      ORDER BY published_at DESC
      LIMIT 5;
    SQL
    
    result = `ssh api "sudo -u postgres psql -d carambus_api_production -c \\"#{sample_sql}\\""`
    puts result
    
    puts "\n3. Sample unassigned videos:"
    sample_sql = <<-SQL
      SELECT external_id, title, published_at::date
      FROM international_videos
      WHERE international_tournament_id IS NULL
      ORDER BY published_at DESC
      LIMIT 5;
    SQL
    
    result = `ssh api "sudo -u postgres psql -d carambus_api_production -c \\"#{sample_sql}\\""`
    puts result
    
    # Video sources
    puts "\n4. Video sources:"
    sources_sql = <<-SQL
      SELECT 
        iss.name,
        iss.source_type,
        COUNT(*) as video_count
      FROM international_videos iv
      JOIN international_sources iss ON iss.id = iv.international_source_id
      GROUP BY iss.name, iss.source_type
      ORDER BY video_count DESC;
    SQL
    
    result = `ssh api "sudo -u postgres psql -d carambus_api_production -c \\"#{sources_sql}\\""`
    puts result
    
    puts "\n" + "="*80
    puts "Current local status:"
    puts "   Videos in database: #{Video.count}"
    puts "\nRun 'rake videos:migrate_via_ssh' to perform migration"
    puts "="*80
  end
end
