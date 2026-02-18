# frozen_string_literal: true

# == Schema Information
#
# Table name: international_videos
#
#  id                         :bigint           not null, primary key
#  description                :text
#  duration                   :integer
#  language                   :string
#  like_count                 :integer
#  metadata                   :jsonb
#  metadata_extracted         :boolean          default(FALSE)
#  metadata_extracted_at      :datetime
#  published_at               :datetime
#  thumbnail_url              :string
#  title                      :string
#  view_count                 :integer
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  discipline_id              :bigint
#  external_id                :string           not null
#  international_source_id    :bigint           not null
#  international_tournament_id :bigint
#
# Indexes
#
#  index_international_videos_on_discipline_id               (discipline_id)
#  index_international_videos_on_external_id                 (external_id) UNIQUE
#  index_international_videos_on_international_source_id     (international_source_id)
#  index_international_videos_on_international_tournament_id (international_tournament_id)
#  index_international_videos_on_metadata_extracted          (metadata_extracted)
#  index_international_videos_on_published_at                (published_at)
#  index_international_videos_on_tournament_and_published    (international_tournament_id,published_at)
#
# Foreign Keys
#
#  fk_rails_...  (discipline_id => disciplines.id)
#  fk_rails_...  (international_source_id => international_sources.id)
#  fk_rails_...  (international_tournament_id => international_tournaments.id)
#
class InternationalVideo < ApplicationRecord
  include LocalProtector

  # Associations
  belongs_to :international_source
  belongs_to :international_tournament, optional: true
  belongs_to :discipline, optional: true

  # Validations
  validates :external_id, presence: true, uniqueness: true
  validates :title, presence: true

  # Scopes
  scope :recent, -> { order(published_at: :desc) }
  scope :unprocessed, -> { where(metadata_extracted: false) }
  scope :processed, -> { where(metadata_extracted: true) }
  scope :by_source, ->(source_id) { where(international_source_id: source_id) }
  scope :by_tournament, ->(tournament_id) { where(international_tournament_id: tournament_id) }
  scope :by_discipline, ->(discipline_id) { where(discipline_id: discipline_id) }
  scope :youtube, -> { joins(:international_source).where(international_sources: { source_type: 'youtube' }) }

  # Display methods
  def display_title
    title.presence || "Video #{external_id}"
  end

  # Get translated title (English) if available, otherwise build from metadata or use original
  def translated_title(locale = :en)
    # Priority 1: Use cached Google Translate translation
    return metadata['translated_title'] if metadata['translated_title'].present?
    
    # Priority 2: Build descriptive title from player names
    if metadata['players'].present? && metadata['players'].size >= 2
      translator = PlayerNameTranslator.new
      match_str = translator.build_match_string(metadata['players'])
      
      parts = []
      parts << metadata['tournament_type'] if metadata['tournament_type'].present?
      parts << metadata['season'] if metadata['season'].present?
      parts << match_str if match_str.present?
      
      return parts.join(' - ') if parts.any?
    end
    
    # Priority 3: Fallback to original title
    title
  end
  
  # Check if video needs translation (non-English title without translation)
  def needs_translation?
    return false if metadata['translated_title'].present?
    return false if title.blank?
    
    # Simple heuristic: if mostly ASCII, probably English
    ascii_chars = title.chars.count { |c| c.ord < 128 }
    ratio = ascii_chars.to_f / title.length
    
    ratio < 0.8 # Less than 80% ASCII means likely non-English
  end

  def duration_formatted
    return nil if duration.blank?
    
    hours = duration / 3600
    minutes = (duration % 3600) / 60
    seconds = duration % 60

    if hours > 0
      format('%d:%02d:%02d', hours, minutes, seconds)
    else
      format('%d:%02d', minutes, seconds)
    end
  end

  def youtube_url
    return nil unless international_source.source_type == 'youtube'
    "https://www.youtube.com/watch?v=#{external_id}"
  end

  def youtube_embed_url
    return nil unless international_source.source_type == 'youtube'
    "https://www.youtube.com/embed/#{external_id}"
  end

  # Extracted metadata accessors
  def extracted_players
    metadata.dig('players') || []
  end

  def extracted_event_name
    metadata.dig('event_name')
  end

  def extracted_round
    metadata.dig('round')
  end

  def extracted_location
    metadata.dig('location')
  end

  def commentary_language
    metadata.dig('commentary_language')
  end

  # Mark as processed
  def mark_processed!(extracted_metadata = {})
    update!(
      metadata_extracted: true,
      metadata_extracted_at: Time.current,
      metadata: metadata.merge(extracted_metadata)
    )
  end

  # Keywords detection for carom billiards
  CAROM_KEYWORDS = [
    # English
    'three cushion', '3-cushion', '3 cushion', 'carom', 'billiard',
    # German
    'dreiband', 'driebanden', 'karambol', 'freie partie',
    # French
    'carambole', 'libre', 'cadre', 'balkline',
    # Korean (당구 = billiards, 3쿠션 = 3-cushion, 캐롬 = carom)
    '당구', '3쿠션', '캐롬', '쿠션',
    # Spanish
    'carambola', 'tres bandas',
    # Dutch
    'driebanden',
    # Turkish
    'üç bant',
    # Tournaments & Organizations
    'world cup', 'world championship', 'european championship',
    'UMB', 'CEB', 'kozoom', 'verhoeven', 'sanchez', 'zanetti',
    'jaspers', 'caudron', 'merckx', 'horn'
  ].freeze

  def self.contains_carom_keywords?(text)
    return false if text.blank?
    text_lower = text.downcase
    CAROM_KEYWORDS.any? { |keyword| text_lower.include?(keyword.downcase) }
  end

  def carom_related?
    contains_carom_keywords?(title) || contains_carom_keywords?(description)
  end

  def contains_carom_keywords?(text)
    self.class.contains_carom_keywords?(text)
  end

  # Discipline detection
  DISCIPLINE_PATTERNS = {
    'Dreiband' => ['3-cushion', '3 cushion', 'three cushion', 'dreiband', 'driebanden'],
    'Freie Partie' => ['libre', 'straight rail', 'freie partie', 'vrije partij'],
    'Cadre' => ['cadre', 'balkline', '47/2', '71/2', '35/2', '52/2']
  }.freeze

  def detect_discipline
    return discipline if discipline.present?

    text = "#{title} #{description}".downcase

    DISCIPLINE_PATTERNS.each do |discipline_name, patterns|
      if patterns.any? { |pattern| text.include?(pattern.downcase) }
        # Try to find discipline, prefer klein (small table) if ambiguous
        found = Discipline.where('name ILIKE ?', "%#{discipline_name}%")
                         .order(Arel.sql("CASE WHEN name ILIKE '%klein%' THEN 0 ELSE 1 END"))
                         .first
        return found if found
      end
    end

    nil
  end

  # Auto-assign discipline
  def auto_assign_discipline!
    detected = detect_discipline
    update(discipline: detected) if detected && discipline.blank?
  end
end
