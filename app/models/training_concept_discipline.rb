class TrainingConceptDiscipline < ApplicationRecord
  include LocalProtector
  belongs_to :training_concept
  belongs_to :discipline
  
  validates :training_concept_id, uniqueness: { scope: :discipline_id }
end
