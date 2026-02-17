# frozen_string_literal: true

# == Schema Information
#
# Table name: international_participations
#
#  id                         :bigint           not null, primary key
#  confirmed                  :boolean          default(FALSE)
#  source                     :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  international_result_id    :bigint
#  international_tournament_id :bigint           not null
#  player_id                  :bigint           not null
#
# Indexes
#
#  index_intl_participations_on_player_and_tournament  (player_id,international_tournament_id) UNIQUE
#  index_international_participations_on_international_result_id     (international_result_id)
#  index_international_participations_on_international_tournament_id (international_tournament_id)
#  index_international_participations_on_player_id                   (player_id)
#
# Foreign Keys
#
#  fk_rails_...  (international_result_id => international_results.id)
#  fk_rails_...  (international_tournament_id => international_tournaments.id)
#  fk_rails_...  (player_id => players.id)
#
class InternationalParticipation < ApplicationRecord
  include LocalProtector

  # Sources for participation data
  VIDEO = 'video'
  RESULT_LIST = 'result_list'
  MANUAL = 'manual'

  SOURCES = [VIDEO, RESULT_LIST, MANUAL].freeze

  # Associations
  belongs_to :player
  belongs_to :international_tournament
  belongs_to :international_result, optional: true

  # Validations
  validates :player_id, uniqueness: { scope: :international_tournament_id }
  validates :source, inclusion: { in: SOURCES }, allow_nil: true

  # Scopes
  scope :confirmed, -> { where(confirmed: true) }
  scope :unconfirmed, -> { where(confirmed: false) }
  scope :by_player, ->(player_id) { where(player_id: player_id) }
  scope :by_tournament, ->(tournament_id) { where(international_tournament_id: tournament_id) }

  # Callbacks
  after_commit :mark_player_as_international, on: :create

  # Mark associated player as international player
  def mark_player_as_international
    player.update(international_player: true) unless player.international_player?
  end

  # Confirm participation
  def confirm!
    update(confirmed: true)
  end

  # Display methods
  def display_source
    case source
    when VIDEO then 'Video'
    when RESULT_LIST then 'Result List'
    when MANUAL then 'Manual Entry'
    else 'Unknown'
    end
  end
end
