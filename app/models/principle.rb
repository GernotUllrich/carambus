class Principle < ApplicationRecord
  PRINCIPLE_TYPES = %w[strategic_maxim measurable_dimension phenomenological].freeze

  enum :principle_type, PRINCIPLE_TYPES.index_with(&:itself), prefix: :principle

  has_many :concept_principles, dependent: :destroy
  has_many :training_concepts, through: :concept_principles

  validates :key,            presence: true, uniqueness: true,
                             format: { with: /\A[a-z_][a-z0-9_]*\z/ }
  validates :label,          presence: true
  validates :principle_type, presence: true
end
