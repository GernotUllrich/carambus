class ValidateTrainingConceptsKindCheck < ActiveRecord::Migration[7.2]
  # v0.9 Phase B — Split-Migration strong_migrations-konform (siehe
  # Tier-1-Muster 140000+140010). Der unvalidated CHECK aus Migration
  # 090000 wird hier nachträglich validiert.
  def change
    validate_check_constraint :training_concepts, name: "training_concepts_kind_check"
  end
end
