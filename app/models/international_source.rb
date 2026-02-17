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
    }
    # Note: Five & Six and CEB Carom channels need to be verified
    # Use: rails international:find_channel_id[fiveandsix]
    # Use: rails international:find_channel_id[ceb]
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
