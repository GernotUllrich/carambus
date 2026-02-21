# frozen_string_literal: true

# == Schema Information
#
# Table name: international_sources
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(TRUE)
#  api_credentials  :text
#  base_url         :string
#  last_scraped_at  :datetime
#  metadata         :jsonb
#  name             :string           not null
#  source_type      :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_international_sources_on_active                  (active)
#  index_international_sources_on_name_and_source_type    (name,source_type) UNIQUE
#  index_international_sources_on_source_type             (source_type)
#
class InternationalSource < ApplicationRecord
  include LocalProtector

  # Source types
  YOUTUBE = 'youtube'
  KOZOOM = 'kozoom'
  FIVESIX = 'fivesix'
  UMB = 'umb'
  CEB = 'ceb'
  MANUAL = 'manual'

  SOURCE_TYPES = [YOUTUBE, KOZOOM, FIVESIX, UMB, CEB, MANUAL].freeze

  # Associations
  has_many :international_videos, dependent: :destroy
  has_many :international_tournaments, dependent: :nullify

  # Validations
  validates :name, presence: true
  validates :source_type, presence: true, inclusion: { in: SOURCE_TYPES }
  validates :name, uniqueness: { scope: :source_type }

  # Encryption for API credentials
  encrypts :api_credentials, deterministic: false

  # Scopes
  scope :active, -> { where(active: true) }
  scope :youtube, -> { where(source_type: YOUTUBE) }
  scope :need_scraping, lambda { |hours_ago = 24|
    where(active: true)
      .where('last_scraped_at IS NULL OR last_scraped_at < ?', hours_ago.hours.ago)
  }

  # Known YouTube channels for carom billiards
  # Note: Channel IDs are needed because modern @handles don't work with for_username API
  # To find a channel ID: Use rake task: rails international:find_channel_id[@handle]
  KNOWN_YOUTUBE_CHANNELS = {
    'kozoom_carom' => {
      name: 'Kozoom Carom',
      channel_id: 'UCOwcct1FjXWzlvmQxaR4Y8Q', # Verified 2026-02-17
      base_url: 'https://www.youtube.com/@kozoom',
      priority: 1,
      description: 'Official Carom Youtube channel of Kozoom, active promoter of billiards since 1998'
    },
    'kozoom_pool' => {
      name: 'Kozoom Pool',
      channel_id: 'UCCgd8_MFdqMHXYSE91KUxQQ', # Verified 2026-02-17
      base_url: 'https://www.youtube.com/@kozoom',
      priority: 3,
      description: 'Official Pool Youtube channel of Kozoom (less relevant for carom)'
    },
    'sponoiter_korea' => {
      name: '스포놀이터 (Sports Playground Korea)',
      channel_id: 'UCh1f8I6U3qo1mt08MR8GoHQ', # Verified 2026-02-18
      base_url: 'https://www.youtube.com/@스포놀이터-n9x',
      priority: 2,
      description: 'Korean carom billiards channel featuring international and Korean tournaments'
    },
    'billiards_network' => {
      name: 'Billiards Network',
      channel_id: 'UC_DhgWl6frARzHLoA3YbrDw', # Verified 2026-02-18
      base_url: 'https://www.youtube.com/@BilliardsNetwork',
      priority: 2,
      description: 'International billiards network with carom and pool content'
    },
    'pro_billiard_tv' => {
      name: 'Pro Billiard TV',
      channel_id: 'UCcNJ3Z708plAMWVkcluIDmA', # Verified 2026-02-18
      base_url: 'https://www.youtube.com/@ProBilliardTV',
      priority: 3,
      description: 'Professional billiards coverage, primarily pool with some carom'
    },
    'i_love_billiards' => {
      name: 'I Love Billiards',
      channel_id: 'UCsU-72Iz-Cp7WtDrSIMo8Ig', # Verified 2026-02-18
      base_url: 'https://www.youtube.com/@ILoveBilliards',
      priority: 3,
      description: 'Billiards enthusiast channel with various disciplines'
    },
    'pba_tv' => {
      name: 'PBA TV',
      channel_id: 'UCuXTHFVxa6tPC_jmqwpyOUA', # Verified 2026-02-18
      base_url: 'https://www.youtube.com/@PBATV',
      priority: 4,
      description: 'Professional Billiards Association TV - mainly pool'
    },
    'ky_phong_viet_art' => {
      name: 'Ky Phong Viet Art',
      channel_id: 'UCrsA1h1rLciorA5TLOT0Hiw', # Verified 2026-02-18
      base_url: 'https://www.youtube.com/@KyPhongVietArt',
      priority: 2,
      description: 'Vietnamese billiards channel featuring Vietnamese and international players'
    },
    'bao_phuong_vinh' => {
      name: 'Bao Phương Vinh',
      channel_id: 'UCXkAGi8082zIUw4zqCMfk_Q', # Verified 2026-02-18
      base_url: 'https://www.youtube.com/@BaoPhuongVinh',
      priority: 2,
      description: 'Vietnamese carom player channel with tournament highlights'
    },
    'predator_cues' => {
      name: 'Predator Cues',
      channel_id: 'UCvHY60Bb4z7simxzpsRIb5Q', # Verified 2026-02-18
      base_url: 'https://www.youtube.com/@PredatorCues',
      priority: 3,
      description: 'Official Predator brand channel - pool and carom equipment, tournaments'
    },
    'carom_lab_korea' => {
      name: '케롬 당구 연구소 (Carom Billiards Lab)',
      channel_id: 'UCsMn2OGmEEeLBxMQkCmlXug', # Verified 2026-02-18
      base_url: 'https://www.youtube.com/@CaromLab',
      priority: 2,
      description: 'Korean carom billiards research and educational content'
    },
    'andykin_mesa1' => {
      name: 'Andykin Sports MESA 1',
      channel_id: 'UCF2hMcLklanWE6YyUffen7w', # Verified 2026-02-18
      base_url: 'https://www.youtube.com/@AndykinMESA1',
      priority: 3,
      description: 'Spanish billiards channel with international carom content'
    },
    'useum_mantang' => {
      name: '웃음만땅',
      channel_id: 'UC5j1KZZRKX2axhW7EwMbdVA', # Verified 2026-02-20
      base_url: 'https://www.youtube.com/channel/UC5j1KZZRKX2axhW7EwMbdVA',
      priority: 2,
      description: 'Korean billiards channel'
    },
    'sbs_sports' => {
      name: 'SBS Sports',
      channel_id: 'UCqsKWTIu7IhBjLFZS2s1ULQ', # Verified 2026-02-20
      base_url: 'https://www.youtube.com/channel/UCqsKWTIu7IhBjLFZS2s1ULQ',
      priority: 2,
      description: 'Korean sports broadcaster with billiards content'
    }
  }.freeze

  # Known federation websites
  KNOWN_FEDERATIONS = {
    'umb' => {
      name: 'Union Mondiale de Billard',
      base_url: 'https://files.umb-carom.org',
      priority: 1
    },
    'ceb' => {
      name: 'Confédération Européenne de Billard',
      base_url: 'https://www.eurobillard.org',
      priority: 2
    }
  }.freeze

  # Seed known sources
  def self.seed_known_sources
    transaction do
      # Seed YouTube channels
      KNOWN_YOUTUBE_CHANNELS.each do |key, data|
        find_or_create_by!(
          name: data[:name],
          source_type: YOUTUBE
        ) do |source|
          source.base_url = data[:base_url]
          source.metadata = {
            key: key,
            priority: data[:priority],
            description: data[:description]
          }
        end
      end

      # Seed federations
      KNOWN_FEDERATIONS.each do |key, data|
        find_or_create_by!(
          name: data[:name],
          source_type: key
        ) do |source|
          source.base_url = data[:base_url]
          source.metadata = {
            key: key,
            priority: data[:priority]
          }
        end
      end
    end
  end

  # Mark as scraped
  def mark_scraped!
    touch(:last_scraped_at)
  end

  # Check if scraping is needed
  def needs_scraping?(hours_ago = 24)
    return false unless active?
    last_scraped_at.nil? || last_scraped_at < hours_ago.hours.ago
  end

  # Display name with type
  def display_name
    "#{name} (#{source_type.upcase})"
  end
end
