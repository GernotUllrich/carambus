class ShotEvent < ApplicationRecord
  include LocalProtector

  # v0.10: nur Einzelball-Ereignisse. Ball-Ball-Kontakte (frueher initial_contact /
  # final_carambolage) liegen in BallCollision.
  EVENT_TYPES    = %w[cushion_contact sperre austausch near_miss].freeze
  BALLS_INVOLVED = %w[b1 b2 b3].freeze
  CUSHIONS       = %w[short_left short_right long_near long_far].freeze

  enum :event_type,       EVENT_TYPES.index_with(&:itself),    prefix: :event
  enum :ball_involved,    BALLS_INVOLVED.index_with(&:itself), prefix: :ball
  enum :cushion_involved, CUSHIONS.index_with(&:itself),       prefix: :cushion

  belongs_to :shot

  validates :sequence_number, presence: true,
                              numericality: { only_integer: true, greater_than: 0 }
  # Reihenfolge zaehlt pro Ball (Design-Doc §5.1/§8).
  validates :sequence_number, uniqueness: { scope: [:shot_id, :ball_involved] }
  validates :event_type, presence: true
  validates :ball_involved, presence: true

  scope :ordered, -> { order(:sequence_number) }
end
