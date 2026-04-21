class TrainingConceptExample < ApplicationRecord
  ROLES = %w[illustrates counter_example].freeze

  enum :role, ROLES.index_with(&:itself), prefix: :role

  belongs_to :training_concept
  belongs_to :training_example

  validates :weight, presence: true,
                     numericality: { only_integer: true, in: 1..5 }
  validates :training_concept_id,
            uniqueness: { scope: :training_example_id }
  validates :sequence_number,
            uniqueness: { scope: :training_concept_id },
            allow_nil: true

  scope :ordered, -> { order(Arel.sql("sequence_number NULLS LAST, id")) }
  scope :by_weight, -> { order(weight: :desc) }
end
