# frozen_string_literal: true

# Seed international sources (YouTube channels, federations, etc.)
# Run with: rails runner db/seeds/international_sources.rb

puts "Seeding international sources..."

# Seed known YouTube channels with their verified channel IDs
# Channel IDs verified using: rails international:find_channel_id[@handle]

InternationalSource.find_or_create_by!(
  name: 'Kozoom Carom',
  source_type: InternationalSource::YOUTUBE
) do |source|
  source.base_url = 'https://www.youtube.com/channel/UCOwcct1FjXWzlvmQxaR4Y8Q'
  source.metadata = {
    key: 'kozoom_carom',
    channel_id: 'UCOwcct1FjXWzlvmQxaR4Y8Q',
    priority: 1,
    description: 'Official Carom Youtube channel of Kozoom, active promoter since 1998',
    estimated_quota: 'high',
    verified_date: '2026-02-17'
  }
  puts "  Created: #{source.name}"
end

InternationalSource.find_or_create_by!(
  name: 'Kozoom Pool',
  source_type: InternationalSource::YOUTUBE
) do |source|
  source.base_url = 'https://www.youtube.com/channel/UCCgd8_MFdqMHXYSE91KUxQQ'
  source.metadata = {
    key: 'kozoom_pool',
    channel_id: 'UCCgd8_MFdqMHXYSE91KUxQQ',
    priority: 3,
    description: 'Official Pool Youtube channel of Kozoom (less relevant for carom)',
    verified_date: '2026-02-17'
  }
  puts "  Created: #{source.name}"
end

InternationalSource.find_or_create_by!(
  name: '스포놀이터 (Sports Playground Korea)',
  source_type: InternationalSource::YOUTUBE
) do |source|
  source.base_url = 'https://www.youtube.com/channel/UCh1f8I6U3qo1mt08MR8GoHQ'
  source.metadata = {
    key: 'sponoiter_korea',
    channel_id: 'UCh1f8I6U3qo1mt08MR8GoHQ',
    priority: 2,
    description: 'Korean carom billiards channel featuring international and Korean tournaments',
    verified_date: '2026-02-18'
  }
  puts "  Created: #{source.name}"
end

# Note: Other channels need to be verified using rake task
# rails international:find_channel_id[fiveandsix]
# rails international:find_channel_id[ceb]

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
