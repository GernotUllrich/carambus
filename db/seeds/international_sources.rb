# frozen_string_literal: true

# Seed international sources (YouTube channels, federations, etc.)
# Run with: rails runner db/seeds/international_sources.rb

puts "Seeding international sources..."

# Seed known YouTube channels with their channel IDs
InternationalSource.find_or_create_by!(
  name: 'Kozoom',
  source_type: InternationalSource::YOUTUBE
) do |source|
  source.base_url = 'https://www.youtube.com/@kozoom'
  source.metadata = {
    key: 'kozoom',
    channel_id: 'UCNbRBHkg56WmZ8NljJOp3SQ',
    priority: 1,
    description: 'Professional carom billiards streaming service',
    estimated_quota: 'high'
  }
  puts "  Created: #{source.name}"
end

InternationalSource.find_or_create_by!(
  name: 'Five & Six',
  source_type: InternationalSource::YOUTUBE
) do |source|
  source.base_url = 'https://www.youtube.com/@fiveandsix'
  source.metadata = {
    key: 'fiveandsix',
    channel_id: 'UCsLw74IkpO3kbRChP0LoMMA',
    priority: 1,
    description: 'Billiard tournament coverage'
  }
  puts "  Created: #{source.name}"
end

InternationalSource.find_or_create_by!(
  name: 'CEB Carom',
  source_type: InternationalSource::YOUTUBE
) do |source|
  source.base_url = 'https://www.youtube.com/@CEBCarom'
  source.metadata = {
    key: 'ceb_carom',
    channel_id: 'UCxkXXKvFLMjBMYVVKHQGsKg',
    priority: 2,
    description: 'Confédération Européenne de Billard'
  }
  puts "  Created: #{source.name}"
end

# Seed federations
InternationalSource.find_or_create_by!(
  name: 'Union Mondiale de Billard',
  source_type: InternationalSource::UMB
) do |source|
  source.base_url = 'https://files.umb-carom.org'
  source.metadata = {
    key: 'umb',
    priority: 1,
    description: 'World governing body for carom billiards'
  }
  puts "  Created: #{source.name}"
end

InternationalSource.find_or_create_by!(
  name: 'Confédération Européenne de Billard',
  source_type: InternationalSource::CEB
) do |source|
  source.base_url = 'https://www.eurobillard.org'
  source.metadata = {
    key: 'ceb',
    priority: 2,
    description: 'European billiards confederation'
  }
  puts "  Created: #{source.name}"
end

puts "International sources seeded successfully!"
puts "Total sources: #{InternationalSource.count}"
