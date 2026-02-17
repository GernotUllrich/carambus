# frozen_string_literal: true

# == Schema Information
#
# Table name: international_results
#
#  id                         :bigint           not null, primary key
#  metadata                   :jsonb
#  player_country             :string
#  player_name                :string
#  points                     :integer
#  position                   :integer
#  prize                      :decimal(10, 2)
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  international_tournament_id :bigint           not null
#  player_id                  :bigint
#
# Indexes
#
#  index_international_results_on_international_tournament_id  (international_tournament_id)
#  index_international_results_on_player_id                    (player_id)
#  index_international_results_on_player_name                  (player_name)
#  index_international_results_on_tournament_and_position      (international_tournament_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (international_tournament_id => international_tournaments.id)
#  fk_rails_...  (player_id => players.id)
#
class InternationalResult < ApplicationRecord
  include LocalProtector

  # Associations
  belongs_to :international_tournament
  belongs_to :player, optional: true

  # Validations
  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :player_name, presence: true, if: -> { player_id.blank? }

  # Scopes
  scope :winners, -> { where(position: 1) }
  scope :podium, -> { where(position: [1, 2, 3]).order(:position) }
  scope :by_player, ->(player_id) { where(player_id: player_id) }
  scope :ordered, -> { order(:position) }

  # Display methods
  def display_name
    player&.fl_name || player_name
  end

  def display_position
    case position
    when 1 then '🥇 1st'
    when 2 then '🥈 2nd'
    when 3 then '🥉 3rd'
    else "#{position}th"
    end
  end

  def medal?
    position.present? && position <= 3
  end

  # Statistics accessors (from metadata JSON)
  def games_played
    metadata.dig('games_played')
  end

  def wins
    metadata.dig('wins')
  end

  def losses
    metadata.dig('losses')
  end

  def average
    metadata.dig('average')
  end

  def high_run
    metadata.dig('high_run')
  end

  def innings
    metadata.dig('innings')
  end

  # Try to match player by name
  def match_player!
    return if player_id.present?
    return if player_name.blank?

    # Try exact match first
    matched_player = Player.find_by('LOWER(fl_name) = ?', player_name.downcase)
    
    # If not found, try fuzzy matching
    if matched_player.nil? && defined?(PlayerMatcher)
      matched_player = PlayerMatcher.new.match(player_name, country: player_country)
    end

    update(player: matched_player) if matched_player
  end
end
