class TrainingConceptRelation < ApplicationRecord
  RELATIONS = %w[teaches applies exemplifies specializes parallels].freeze

  enum :relation, RELATIONS.index_with(&:itself), prefix: :relation

  belongs_to :source_concept,
             class_name: "TrainingConcept",
             inverse_of: :outgoing_relations
  belongs_to :target_concept,
             class_name: "TrainingConcept",
             inverse_of: :incoming_relations

  validates :relation, presence: true
  validates :source_concept_id,
            uniqueness: { scope: [:target_concept_id, :relation] }
  validate  :no_self_loop

  private

  def no_self_loop
    return if source_concept_id.nil? || target_concept_id.nil?
    return unless source_concept_id == target_concept_id

    errors.add(:target_concept_id, "cannot equal source_concept_id")
  end
end
