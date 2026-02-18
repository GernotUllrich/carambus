# frozen_string_literal: true

# == Schema Information
#
# Table name: international_tournaments
#
#  id                      :bigint           not null, primary key
#  country                 :string
#  data                    :jsonb
#  end_date                :date
#  location                :string
#  name                    :string           not null
#  organizer               :string
#  prize_money             :decimal(12, 2)
#  source_url              :string
#  start_date              :date
#  tournament_type         :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  discipline_id           :bigint           not null
#  external_id             :string
#  international_source_id :bigint
#
# Indexes
#
#  index_international_tournaments_on_country                    (country)
#  index_international_tournaments_on_discipline_id              (discipline_id)
#  index_international_tournaments_on_international_source_id    (international_source_id)
#  index_international_tournaments_on_organizer                  (organizer)
#  index_international_tournaments_on_start_date_and_tournament_type  (start_date,tournament_type)
#  index_intl_tournaments_on_external_id_and_source              (external_id,international_source_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (discipline_id => disciplines.id)
#  fk_rails_...  (international_source_id => international_sources.id)
#
class InternationalTournament < ApplicationRecord
  include LocalProtector

  # Tournament types
  WORLD_CUP = 'world_cup'
  WORLD_CHAMPIONSHIP = 'world_championship'
  EUROPEAN_CHAMPIONSHIP = 'european_championship'
  NATIONAL_CHAMPIONSHIP = 'national_championship'
  LEAGUE = 'league'
  INVITATION = 'invitation'
  OTHER = 'other'

  TOURNAMENT_TYPES = [
    WORLD_CUP,
    WORLD_CHAMPIONSHIP,
    EUROPEAN_CHAMPIONSHIP,
    NATIONAL_CHAMPIONSHIP,
    LEAGUE,
    INVITATION,
    OTHER
  ].freeze

  # Associations
  belongs_to :discipline
  belongs_to :international_source, optional: true
  has_many :international_results, dependent: :destroy
  has_many :international_videos, dependent: :nullify
  has_many :international_participations, dependent: :destroy
  has_many :players, through: :international_participations
  has_one :tournament, dependent: :nullify # Link to local Tournament if created

  # Validations
  validates :name, presence: true
  validates :tournament_type, inclusion: { in: TOURNAMENT_TYPES }, allow_nil: true
  validates :external_id, uniqueness: { scope: :international_source_id }, allow_nil: true

  # Scopes
  scope :upcoming, -> { where('start_date >= ?', Date.today).order(start_date: :asc) }
  scope :past, -> { where('end_date < ?', Date.today).order(start_date: :desc) }
  scope :current, lambda {
    where('start_date <= ? AND end_date >= ?', Date.today, Date.today)
  }
  scope :by_type, ->(type) { where(tournament_type: type) }
  scope :by_discipline, ->(discipline_id) { where(discipline_id: discipline_id) }
  scope :in_year, ->(year) { where('EXTRACT(YEAR FROM start_date) = ?', year) }

  # Display methods
  def display_name
    parts = [name]
    parts << "(#{location})" if location.present?
    parts << date_range if start_date.present?
    parts.join(' ')
  end

  def date_range
    return start_date.to_s if end_date.blank? || start_date == end_date
    "#{start_date} - #{end_date}"
  end

  def year
    start_date&.year
  end

  def status
    return :upcoming if start_date.present? && start_date > Date.today
    return :current if start_date.present? && end_date.present? &&
                       start_date <= Date.today && end_date >= Date.today
    return :past if end_date.present? && end_date < Date.today
    :unknown
  end

  # Check if tournament is a major championship
  def major_championship?
    [WORLD_CHAMPIONSHIP, EUROPEAN_CHAMPIONSHIP].include?(tournament_type)
  end

  # Get winner
  def winner
    international_results.order(:position).first
  end

  # Get top N results
  def top_results(limit = 8)
    international_results.order(:position).limit(limit)
  end

  # Create or update result
  def add_result(player_name:, position:, points: nil, prize: nil, player: nil, metadata: {})
    international_results.create_or_find_by!(
      player: player,
      player_name: player_name
    ) do |result|
      result.position = position
      result.points = points
      result.prize = prize
      result.metadata = metadata
    end
  end
end
