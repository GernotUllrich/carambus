class TableZone < ApplicationRecord
  ZONE_TYPES = %w[band_strip corner_region line_passage custom].freeze

  enum :zone_type, ZONE_TYPES.index_with(&:itself), prefix: :zone

  has_many :ball_configuration_zones, dependent: :destroy
  has_many :ball_configurations, through: :ball_configuration_zones

  validates :key,       presence: true, uniqueness: true,
                        format: { with: /\A[a-z_][a-z0-9_]*\z/ }
  validates :label,     presence: true
  validates :zone_type, presence: true
end
