class BallConfigurationZone < ApplicationRecord
  WHICH_BALLS = %w[b1 b2 b3 any].freeze
  ROLES       = %w[target source via].freeze

  enum :which_ball, WHICH_BALLS.index_with(&:itself), prefix: :ball
  enum :role,       ROLES.index_with(&:itself),       prefix: :role

  belongs_to :ball_configuration
  belongs_to :table_zone

  validates :which_ball, presence: true
  validates :role,       presence: true
  validates :ball_configuration_id,
            uniqueness: { scope: [:table_zone_id, :which_ball, :role] }
end
