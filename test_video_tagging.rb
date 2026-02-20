#!/usr/bin/env ruby
# frozen_string_literal: true

# Test Script für Video-Tagging-System
# Usage: bin/rails runner test_video_tagging.rb

puts "=" * 80
puts "VIDEO TAGGING SYSTEM - TEST SCRIPT"
puts "=" * 80
puts

# 1. Test: Verfügbare Tag-Gruppen anzeigen
puts "1. VIDEO TAG GROUPS"
puts "-" * 80
InternationalHelper::VIDEO_TAG_GROUPS.each do |group_name, config|
  puts "#{config[:icon]}  #{group_name}: #{config[:tags].size} tags"
  if group_name == 'Top Players'
    puts "   Top 5: #{config[:tags].take(5).join(', ')}"
  else
    puts "   Tags: #{config[:tags].join(', ')}"
  end
  puts
end

# 2. Test: Player Tags by Country
puts "2. TOP 32 PLAYERS BY COUNTRY"
puts "-" * 80
InternationalHelper.player_tags_by_country.each do |country, players|
  puts "🏁 #{country}: #{players.size} players"
  players.take(3).each do |player|
    puts "   ##{player[:rank].to_s.rjust(2)} #{player[:name]} (#{player[:tag]})"
  end
  puts
end

# 3. Test: Video mit Auto-Detection
puts "3. AUTO-DETECTION TEST"
puts "-" * 80

if Video.any?
  video = Video.first
  puts "Testing with: #{video.title}"
  puts
  
  puts "Content Type Tags:"
  content_tags = video.detect_content_type_tags
  if content_tags.any?
    content_tags.each { |tag| puts "  ✓ #{tag}" }
  else
    puts "  (keine erkannt)"
  end
  puts
  
  puts "Player Tags:"
  player_tags = video.detect_player_tags
  if player_tags.any?
    player_tags.each { |tag| puts "  ✓ #{tag}" }
  else
    puts "  (keine erkannt)"
  end
  puts
  
  puts "Quality Tags:"
  quality_tags = video.detect_quality_tags
  if quality_tags.any?
    quality_tags.each { |tag| puts "  ✓ #{tag}" }
  else
    puts "  (keine erkannt)"
  end
  puts
  
  puts "Alle erkannten Tags: #{video.detect_all_tags.join(', ')}"
  puts
  
  # 4. Test: Auto-Tagging
  puts "4. AUTO-TAGGING TEST"
  puts "-" * 80
  
  puts "Aktuelle Tags: #{video.tags.inspect}"
  puts "Vorgeschlagene Tags: #{video.suggested_tags.join(', ')}"
  puts
  
  if video.suggested_tags.any?
    puts "Möchten Sie auto-tagging durchführen? (Video wird NICHT gespeichert)"
    puts "Würde folgende Tags hinzufügen: #{video.suggested_tags.join(', ')}"
  end
else
  puts "⚠️  Keine Videos in der Datenbank gefunden!"
  puts "Importieren Sie zuerst Videos mit ScrapeYoutubeJob"
end
puts

# 5. Test: Scope-Tests
puts "5. SCOPE TESTS"
puts "-" * 80

puts "Videos insgesamt: #{Video.count}"
puts "Videos mit Tags: #{Video.count - Video.without_tags.count}"
puts "Videos ohne Tags: #{Video.without_tags.count}"
puts

if Video.count > 0 && Video.count != Video.without_tags.count
  # Finde ein Video mit Tags
  tagged_video = Video.where("jsonb_array_length(data->'tags') > 0").first
  if tagged_video
    puts "Beispiel: Videos mit Tag '#{tagged_video.tags.first}':"
    Video.with_tag(tagged_video.tags.first).limit(3).each do |v|
      puts "  - #{v.title} (Tags: #{v.tags.join(', ')})"
    end
  end
end
puts

# 6. Test: Statistics
puts "6. TAG STATISTICS"
puts "-" * 80

tag_counts = Video.where("data->'tags' IS NOT NULL")
                  .pluck(Arel.sql("jsonb_array_elements_text(data->'tags')"))
                  .group_by(&:itself)
                  .transform_values(&:count)
                  .sort_by { |_, count| -count }
                  .take(10)

if tag_counts.any?
  puts "Top 10 meist verwendete Tags:"
  tag_counts.each_with_index do |(tag, count), index|
    puts "  #{(index + 1).to_s.rjust(2)}. #{tag.ljust(20)} (#{count}x)"
  end
else
  puts "Keine Tags gefunden. Führen Sie auto_tag! auf Videos aus."
end
puts

# 7. Test: Helper Methods
puts "7. HELPER METHODS TEST"
puts "-" * 80
puts "Badge Klassen für Content Types:"
['full_game', 'shot_of_the_day', 'high_run', 'training'].each do |tag|
  helper = Object.new.extend(InternationalHelper)
  badge_class = helper.video_tag_badge_class(tag)
  puts "  #{tag.ljust(20)} → #{badge_class}"
end
puts

puts "=" * 80
puts "TEST ABGESCHLOSSEN"
puts "=" * 80
puts
puts "Nächste Schritte:"
puts "1. Videos importieren: ScrapeYoutubeJob.perform_later"
puts "2. Auto-Tagging: Video.without_tags.find_each(&:auto_tag!)"
puts "3. Filter testen: Video.with_tag('full_game')"
puts
