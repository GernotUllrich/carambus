class ConceptPrinciple < ApplicationRecord
  RELATIONS = %w[teaches applies exemplifies].freeze

  enum :relation, RELATIONS.index_with(&:itself), prefix: :relation

  belongs_to :training_concept
  belongs_to :principle

  validates :relation, presence: true
  validates :training_concept_id,
            uniqueness: { scope: [:principle_id, :relation] }
end
