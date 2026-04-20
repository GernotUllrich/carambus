class CreatePrinciples < ActiveRecord::Migration[7.2]
  # v0.8 Tier 2: first-class Principle entity. Holds Gretillat's and
  # Weingartner's strategic / measurable / phenomenological principles so
  # TrainingConcepts can reference them via concept_principles.
  def change
    create_table :principles do |t|
      t.string  :key,              null: false
      t.string  :label,            null: false
      t.string  :principle_type,   null: false
      t.text    :description
      t.string  :gretillat_ref
      t.string  :weingartner_ref
      t.integer :importance_order

      t.timestamps
    end

    add_index :principles, :key, unique: true

    add_check_constraint :principles,
      "principle_type IN ('strategic_maxim','measurable_dimension','phenomenological')",
      name: "principles_principle_type_check"
  end
end
