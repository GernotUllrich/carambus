# frozen_string_literal: true

# == Schema Information
#
# Table name: videos
#
#  id                      :bigint           not null, primary key
#  data                    :jsonb
#  description             :text
#  duration                :integer
#  external_id             :string           not null
#  language                :string
#  like_count              :integer
#  metadata_extracted      :boolean          default(FALSE)
#  metadata_extracted_at   :datetime
#  published_at            :datetime
#  thumbnail_url           :string
#  title                   :string
#  videoable_type          :string
#  view_count              :integer
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  discipline_id           :bigint
#  international_source_id :bigint
#  videoable_id            :bigint
#
# Indexes
#
#  idx_videos_on_videoable_and_published       (videoable_type,videoable_id,published_at)
#  index_videos_on_discipline_id               (discipline_id)
#  index_videos_on_external_id                 (external_id) UNIQUE
#  index_videos_on_international_source_id     (international_source_id)
#  index_videos_on_metadata_extracted          (metadata_extracted)
#  index_videos_on_published_at                (published_at)
#  index_videos_on_videoable                   (videoable_type,videoable_id)
#
# Foreign Keys
#
#  fk_rails_...  (discipline_id => disciplines.id)
#  fk_rails_...  (international_source_id => international_sources.id)
#
class Video < ApplicationRecord
  include LocalProtector

  # Polymorphe Association - Video kann zu Tournament, Game oder Player gehören
  belongs_to :videoable, polymorphic: true, optional: true
  belongs_to :international_source
  belongs_to :discipline, optional: true

  # Validations
  validates :external_id, presence: true, uniqueness: true
  validates :title, presence: true

  # Scopes
  scope :recent, -> { order(published_at: :desc) }
  scope :for_tournaments, -> { where(videoable_type: "Tournament") }
  scope :for_games, -> { where(videoable_type: "Game") }
  scope :for_players, -> { where(videoable_type: "Player") }
  scope :unassigned, -> { where(videoable_id: nil) }
  scope :unprocessed, -> { where(metadata_extracted: false) }
  scope :processed, -> { where(metadata_extracted: true) }
  scope :by_source, ->(source_id) { where(international_source_id: source_id) }
  scope :by_discipline, ->(discipline_id) { where(discipline_id: discipline_id) }
  scope :youtube, -> { joins(:international_source).where(international_sources: { source_type: "youtube" }) }
  scope :fivesix, -> { joins(:international_source).where(international_sources: { source_type: "fivesix" }) }
  scope :supported_platforms, lambda {
    joins(:international_source).where(international_sources: { source_type: %w[youtube fivesix kozoom] })
  }
  scope :visible, -> { where(hidden: false) }
  scope :hidden_videos, -> { where(hidden: true) }

  # Tag filtering scopes
  scope :with_tag, ->(tag) { where("videos.data @> ?", { tags: [tag] }.to_json) }
  scope :with_any_tag, ->(tags) { where("videos.data->'tags' ?| ARRAY[:tags]::text[]", tags: tags) }
  scope :with_all_tags, ->(tags) { where("videos.data->'tags' ?& ARRAY[:tags]::text[]", tags: tags) }
  scope :without_tags, -> { where("videos.data->'tags' IS NULL OR jsonb_array_length(videos.data->'tags') = 0") }

  # Display methods
  def display_title
    title.presence || "Video #{external_id}"
  end

  # Get translated title (English) if available, otherwise build from metadata or use original
  def translated_title(locale = :en)
    # Priority 1: Use cached Google Translate translation
    return json_data["translated_title"] if json_data["translated_title"].present?

    # Priority 2: Build descriptive title from player names
    if json_data["players"].present? && json_data["players"].size >= 2
      # NOTE: PlayerNameTranslator might need to be added if not present
      parts = []
      parts << json_data["tournament_type"] if json_data["tournament_type"].present?
      parts << json_data["season"] if json_data["season"].present?
      parts << json_data["players"].join(" vs ") if json_data["players"].present?

      return parts.join(" - ") if parts.any?
    end

    # Priority 3: Fallback to original title
    title
  end

  # Check if video needs translation (non-English title without translation)
  def needs_translation?
    return false if json_data["translated_title"].present?
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
      format("%d:%02d:%02d", hours, minutes, seconds)
    else
      format("%d:%02d", minutes, seconds)
    end
  end

  def youtube_url
    watch_url
  end

  def youtube_embed_url
    embed_url
  end

  def watch_url
    case international_source&.source_type
    when "youtube"
      "https://www.youtube.com/watch?v=#{external_id}"
    when "fivesix"
      "https://vod.sooplive.co.kr/player/#{external_id}"
    else
      nil
    end
  end

  def embed_url
    case international_source&.source_type
    when "youtube"
      # Keep original behavior for youtube
      "https://www.youtube.com/embed/#{external_id}"
    when "fivesix"
      is_live = !!(json_data["is_live"] || (data.is_a?(Hash) && data["is_live"]))
      if is_live
        "https://play.sooplive.co.kr/embed/#{external_id}?wMode=transparent&szIframeWidth=100%25&szIframeHeight=100%25&szLanguage=en_US"
      else
        "https://vod.sooplive.co.kr/player/#{external_id}/embed?wMode=transparent&szIframeWidth=100%25&szIframeHeight=100%25&szLanguage=en_US&bChat=false"
      end
    else
      nil
    end
  end

  def player
    json_data["player"]
  end

  # Metadata accessors
  def json_data
    @json_data ||= begin
      return {} if data.blank?

      data.is_a?(String) ? JSON.parse(data) : data
    rescue JSON::ParserError
      {}
    end
  end

  def extracted_players
    json_data["players"] || []
  end

  def extracted_event_name
    json_data["event_name"]
  end

  def extracted_round
    json_data["round"]
  end

  def extracted_location
    json_data["location"]
  end

  def commentary_language
    json_data["commentary_language"]
  end

  # Mark as processed
  def mark_processed!(extracted_metadata = {})
    update!(
      metadata_extracted: true,
      metadata_extracted_at: Time.current,
      data: json_data.merge(extracted_metadata)
    )
  end

  # Keywords detection for carom billiards
  CAROM_KEYWORDS = [
    # English
    "three cushion", "3-cushion", "3 cushion", "carom", "billiard",
    # German
    "dreiband", "driebanden", "karambol", "freie partie",
    # French
    "carambole", "libre", "cadre", "balkline",
    # Korean (당구 = billiards, 3쿠션 = 3-cushion, 캐롬 = carom, 케롬 = carom variant)
    "당구", "3쿠션", "캐롬", "쿠션", "케롬",
    # Vietnamese (bi-a = billiards, carom)
    "bi-a", "bida", "carom", "ba băng",
    # Spanish
    "carambola", "tres bandas", "banda",
    # Dutch
    "driebanden",
    # Turkish
    "üç bant", "bilardo",
    # Tournaments & Organizations
    "world cup", "world championship", "european championship",
    "UMB", "CEB", "kozoom", "predator",
    # Famous Players (helps identify carom content)
    "verhoeven", "sanchez", "zanetti", "jaspers", "caudron", "merckx", "horn",
    "blomdahl", "sayginer", "tasdemir", "polychronopoulos", "forthomme",
    "bao phuong", "tran quyet", "cho myung", "kim haeng"
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
    "Dreiband" => ["3-cushion", "3 cushion", "three cushion", "dreiband", "driebanden"],
    "Freie Partie" => ["libre", "straight rail", "freie partie", "vrije partij"],
    "Cadre" => ["cadre", "balkline", "47/2", "71/2", "35/2", "52/2"]
  }.freeze

  def detect_discipline
    return discipline if discipline.present?

    text = "#{title} #{description}".downcase

    DISCIPLINE_PATTERNS.each do |discipline_name, patterns|
      next unless patterns.any? { |pattern| text.include?(pattern.downcase) }

      # Try to find discipline, prefer klein (small table) if ambiguous
      found = Discipline.where("name ILIKE ?", "%#{discipline_name}%")
                        .order(Arel.sql("CASE WHEN name ILIKE '%klein%' THEN 0 ELSE 1 END"))
                        .first
      return found if found
    end

    nil
  end

  # Auto-assign discipline
  def auto_assign_discipline!
    detected = detect_discipline
    update(discipline: detected) if detected && discipline.blank?
  end

  # ============================================================================
  # VIDEO TAGGING SYSTEM
  # ============================================================================

  # Content type detection patterns
  CONTENT_TYPE_DETECTORS = {
    "full_game" => lambda { |video|
      # Long duration + matchup pattern + player names detected
      has_duration = video.duration && video.duration > 1800
      has_vs_pattern = video.title.match?(/\bvs\.?\b|\bgegen\b/i)
      has_dash_pattern = video.title.match?(/\s+-\s+/) # Dash with spaces (common in matchups)
      has_matchup = has_vs_pattern || has_dash_pattern

      # Check if we can detect 2+ player names in title
      detected_players = video.detect_player_tags
      has_players = detected_players.size >= 2

      has_duration && has_matchup && has_players
    },
    "shot_of_the_day" => lambda { |video|
      video.duration && video.duration < 300 &&
        video.title.downcase.match?(/shot|trick|amazing|incredible|unbelievable/)
    },
    "high_run" => lambda { |video|
      title = video.title.downcase
      title.match?(/high run|serie|series/i) &&
        title.scan(/\d+/).any? { |n| n.to_i > 10 }
    },
    "highlights" => lambda { |video|
      video.title.downcase.match?(/highlights?|best of|top \d+/)
    },
    "training" => lambda { |video|
      video.title.downcase.match?(/training|lesson|tutorial|drill/)
    }
  }.freeze

  # Quality detection patterns
  QUALITY_DETECTORS = {
    "4k" => ->(video) { video.title.match?(/\b4k\b|\b2160p\b/i) },
    "hd" => ->(video) { video.title.match?(/\bhd\b|\b1080p\b|\b720p\b/i) },
    "slow_motion" => ->(video) { video.title.downcase.match?(/slow motion|slow-mo|slowmo/) },
    "multi_angle" => ->(video) { video.title.downcase.match?(/multi[- ]?angle|multiple angles/) }
  }.freeze

  # Get current tags from data JSONB
  def tags
    json_data["tags"] || []
  end

  # Set tags in data JSONB
  def tags=(new_tags)
    self.data = json_data.merge("tags" => new_tags.uniq.compact)
  end

  # Add a tag
  def add_tag(tag)
    current_tags = tags
    return if current_tags.include?(tag)

    self.tags = current_tags + [tag]
    save
  end

  # Remove a tag
  def remove_tag(tag)
    self.tags = tags - [tag]
    save
  end

  # Check if video has a specific tag
  def tagged_with?(tag)
    tags.include?(tag)
  end

  # Detect player tags from title and description
  def detect_player_tags
    detected = []
    text = "#{title} #{description}".upcase

    InternationalHelper::WORLD_CUP_TOP_32.each do |tag, info|
      detected << tag.downcase if text.include?(tag.upcase) || text.include?(info[:full_name].upcase)
    end

    detected
  end

  # Detect content type tags
  def detect_content_type_tags
    detected = []

    CONTENT_TYPE_DETECTORS.each do |tag, detector|
      detected << tag if detector.call(self)
    end

    detected
  end

  # Detect quality tags
  def detect_quality_tags
    detected = []

    QUALITY_DETECTORS.each do |tag, detector|
      detected << tag if detector.call(self)
    end

    detected
  end

  # Detect all tags (players + content types + quality)
  def detect_all_tags
    (detect_player_tags + detect_content_type_tags + detect_quality_tags).uniq
  end

  # Auto-tag video with detected tags
  def auto_tag!
    detected_tags = detect_all_tags
    return if detected_tags.empty?

    current_tags = tags
    new_tags = (current_tags + detected_tags).uniq

    update(data: json_data.merge(
      "tags" => new_tags,
      "auto_tagged_at" => Time.current.iso8601
    ))
  end

  # Get auto-detected tags (without saving)
  def suggested_tags
    detect_all_tags - tags
  end

  # Admin methods for hiding/showing videos
  def hide!
    update(hidden: true)
  end

  def unhide!
    update(hidden: false)
  end

  def toggle_hidden!
    update(hidden: !hidden)
  end
end
