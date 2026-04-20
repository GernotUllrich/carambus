class BallConfiguration < ApplicationRecord
  TABLE_VARIANTS = %w[match halbmatch klein].freeze
  GATHER_STATES = %w[pre_gather gathering post_gather].freeze

  has_one :start_position, dependent: :restrict_with_error
  has_many :ending_shots,
           class_name: "Shot",
           foreign_key: :end_ball_configuration_id,
           dependent: :nullify,
           inverse_of: :end_ball_configuration

  enum :table_variant, TABLE_VARIANTS.index_with(&:itself), prefix: :table
  enum :gather_state, GATHER_STATES.index_with(&:itself), prefix: :gather

  validates :table_variant, presence: true
  validates :gather_state, presence: true
  validates :b1_x, :b1_y, :b2_x, :b2_y, :b3_x, :b3_y,
            presence: true,
            numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }

  # Normalized ball positions keyed by role. Coordinates are relative to table
  # length (x) and width (y); multiply by the chosen table_variant's cm
  # dimensions to de-normalize at render time.
  def balls
    {
      b1: [b1_x, b1_y],
      b2: [b2_x, b2_y],
      b3: [b3_x, b3_y]
    }
  end
end
