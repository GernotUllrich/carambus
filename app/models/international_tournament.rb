# frozen_string_literal: true

# InternationalTournament is a STI subclass of Tournament
# for international carom billiards tournaments (World Cups, World Championships, etc.)
class InternationalTournament < Tournament
  include PlaceholderAware
  
  # WORKAROUND: Rails STI polymorphic association bug - organizer association doesn't work properly
  # in subclasses, so we make it optional and handle validation manually
  belongs_to :organizer, polymorphic: true, optional: true
  belongs_to :season, optional: true
  
  # International tournaments use international_source_id instead of region_id
  belongs_to :international_source, optional: true
  
  # Inherited from Tournament:
  # has_many :seedings
  # has_many :games
  # has_many :players, through: :seedings
  
  validates :international_source_id, presence: true, if: -> { external_id.present? }
  validates :external_id, uniqueness: { scope: :international_source_id }, allow_nil: true
  
  # Manual validation: Require organizer_id (since association doesn't work)
  validates :organizer_id, presence: true, message: "muss ausgefüllt werden"
  validates :organizer_type, presence: true
  
  # Scopes
  scope :from_umb, -> { joins(:international_source).where(international_sources: { source_type: 'umb' }) }
  scope :upcoming, -> { where('date >= ?', Date.today).order(date: :asc) }
  
  # Class methods for filtering (data is serialized TEXT, not JSONB)
  def self.by_type(type)
    return all if type.blank?
    
    # Filter in Ruby since data is serialized
    all.select do |tournament|
      tournament.tournament_type == type
    end
  end
  
  def self.official_umb_only
    # Filter in Ruby since data is serialized
    all.select do |tournament|
      tournament.official_umb?
    end
  end
  
  # Tournament types for filters
  TOURNAMENT_TYPES = %w[world_cup world_championship european_championship masters grand_prix].freeze
  
  # Define placeholder fields (inherited from Tournament)
  def self.placeholder_fields
    {
      discipline_id: -> { Discipline.find_by(name: 'Unknown Discipline')&.id },
      season_id: -> { Season.find_by(name: 'Unknown Season')&.id },
      location_id: -> { Location.find_by(name: 'Unknown Location')&.id },
      organizer_id: -> { Region.find_by(shortname: 'UNKNOWN')&.id }
    }
  end
  
  # View compatibility methods (alias to Tournament fields)
  def name
    title
  end
  
  def location
    location_text
  end
  
  def start_date
    date&.to_date
  end
  
  def date_range
    return date.to_s unless end_date
    "#{date.strftime('%d %b')} - #{end_date.strftime('%d %b %Y')}"
  end
  
  def official_umb?
    json_data['umb_official'] == true || json_data['umb_official'] == 'true'
  end
  
  # Helper methods to access data stored in JSON
  def tournament_type
    json_data['tournament_type']
  end
  
  def country
    json_data['country']
  end
  
  def organizer
    json_data['organizer']
  end
  
  def pdf_links
    json_data['pdf_links'] || {}
  end
  
  private
  
  def json_data
    @json_data ||= begin
      return {} if data.blank?
      data.is_a?(String) ? JSON.parse(data) : data
    rescue JSON::ParserError
      {}
    end
  end
end
