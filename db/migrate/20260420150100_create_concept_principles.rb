class CreateConceptPrinciples < ActiveRecord::Migration[7.2]
  # v0.8 Tier 2: join between TrainingConcept and Principle with a typed
  # relation (teaches | applies | exemplifies). notes is DE-only plain
  # text (Translatable explicitly declined per Tier 2 scoping).
  def change
    create_table :concept_principles do |t|
      t.references :training_concept, null: false, foreign_key: true
      t.references :principle,        null: false, foreign_key: true
      t.string     :relation,         null: false
      t.text       :notes

      t.timestamps
    end

    add_index :concept_principles,
      [:training_concept_id, :principle_id, :relation],
      unique: true, name: "idx_concept_principle_unique"

    add_check_constraint :concept_principles,
      "relation IN ('teaches','applies','exemplifies')",
      name: "concept_principles_relation_check"
  end
end
