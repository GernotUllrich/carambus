class ValidateTrainingConceptAxisCheck < ActiveRecord::Migration[7.2]
  def change
    validate_check_constraint :training_concepts, name: "training_concepts_axis_check"
  end
end
