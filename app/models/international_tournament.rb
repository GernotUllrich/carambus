# frozen_string_literal: true

# InternationalTournament is a STI subclass of Tournament
# for international carom billiards tournaments (World Cups, World Championships, etc.)
class InternationalTournament < Tournament
  # International tournaments use international_source_id instead of region_id
  belongs_to :international_source, optional: true
  
  # Inherited from Tournament:
  # has_many :seedings
  # has_many :games
  # has_many :players, through: :seedings
  
  validates :international_source_id, presence: true, if: -> { external_id.present? }
  validates :external_id, uniqueness: { scope: :international_source_id }, allow_nil: true
  
  # Scopes
  scope :from_umb, -> { joins(:international_source).where(international_sources: { source_type: 'umb' }) }
  scope :world_cups, -> { where("data->>'tournament_type' = ?", 'world_cup') }
  scope :world_championships, -> { where("data->>'tournament_type' = ?", 'world_championship') }
  scope :upcoming, -> { where('date >= ?', Date.today).order(date: :asc) }
  scope :by_type, ->(type) { where("data->>'tournament_type' = ?", type) if type.present? }
  scope :by_discipline, ->(discipline_id) { where(discipline_id: discipline_id) if discipline_id.present? }
  scope :in_year, ->(year) { where('EXTRACT(YEAR FROM date) = ?', year) if year.present? }
  scope :official_umb, -> { where("data->>'umb_official' = ?", 'true') }
  
  # Tournament types for filters
  TOURNAMENT_TYPES = %w[world_cup world_championship european_championship masters grand_prix].freeze
  
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
