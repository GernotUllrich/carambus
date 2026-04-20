class BallConfiguration < ApplicationRecord
  TABLE_VARIANTS   = %w[match halbmatch klein].freeze
  GATHER_STATES    = %w[pre_gather gathering post_gather].freeze
  FLOW_DIRECTIONS  = %w[centrifugal centripetal].freeze
  ORIENTATIONS     = %w[gather distribute hybrid].freeze
  BIAIS_CLASSES    = %w[imperceptible faible moyen prononce extreme].freeze
  TARGET_CUSHIONS  = %w[short_left short_right long_near long_far].freeze
  POSITION_TYPES   = %w[exact approximate qualitative].freeze

  has_one :start_position, dependent: :restrict_with_error
  has_many :ending_shots,
           class_name: "Shot",
           foreign_key: :end_ball_configuration_id,
           dependent: :nullify,
           inverse_of: :end_ball_configuration

  enum :table_variant,   TABLE_VARIANTS.index_with(&:itself),  prefix: :table
  enum :gather_state,    GATHER_STATES.index_with(&:itself),   prefix: :gather
  enum :flow_direction,  FLOW_DIRECTIONS.index_with(&:itself), prefix: :flow
  enum :orientation,     ORIENTATIONS.index_with(&:itself),    prefix: :orient
  enum :biais_class,     BIAIS_CLASSES.index_with(&:itself),   prefix: :biais
  enum :target_cushion,  TARGET_CUSHIONS.index_with(&:itself), prefix: :cushion
  enum :position_type,   POSITION_TYPES.index_with(&:itself),  prefix: :position

  validates :table_variant, presence: true
  validates :gather_state,  presence: true
  validates :position_type, presence: true
  validates :b1_x, :b1_y, :b2_x, :b2_y, :b3_x, :b3_y,
            presence: true,
            numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
  validates :biais_degrees,
            numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 },
            allow_nil: true

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
