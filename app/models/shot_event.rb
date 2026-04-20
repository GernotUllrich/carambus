class ShotEvent < ApplicationRecord
  EVENT_TYPES    = %w[initial_contact cushion_contact sperre austausch final_carambolage near_miss].freeze
  BALLS_INVOLVED = %w[b1 b2 b3].freeze
  CUSHIONS       = %w[short_left short_right long_near long_far].freeze

  enum :event_type,       EVENT_TYPES.index_with(&:itself),    prefix: :event
  enum :ball_involved,    BALLS_INVOLVED.index_with(&:itself), prefix: :ball
  enum :cushion_involved, CUSHIONS.index_with(&:itself),       prefix: :cushion

  belongs_to :shot

  validates :sequence_number, presence: true,
                              numericality: { only_integer: true, greater_than: 0 }
  validates :sequence_number, uniqueness: { scope: :shot_id }
  validates :event_type, presence: true

  scope :ordered, -> { order(:sequence_number) }
end
