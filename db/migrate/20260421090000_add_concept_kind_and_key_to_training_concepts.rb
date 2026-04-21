class AddConceptKindAndKeyToTrainingConcepts < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  # v0.9 Phase B: TrainingConcept absorbiert die Principle-Struktur.
  # Fünf neue Spalten, alle nullable (damit reine Topic-Concepts, die
  # nicht aus der Principle-Tradition stammen, ohne key/kind/refs
  # leben dürfen):
  #   kind             — {topic, strategic_maxim, measurable_dimension,
  #                       phenomenological, technique, system}
  #   key              — slug (unique where not null)
  #   gretillat_ref    — Quellenverweis Gretillat
  #   weingartner_ref  — Quellenverweis Weingartner
  #   importance_order — Reihungsanker für Listenansichten
  def change
    add_column :training_concepts, :kind,             :string
    add_column :training_concepts, :key,              :string
    add_column :training_concepts, :gretillat_ref,    :string
    add_column :training_concepts, :weingartner_ref,  :string
    add_column :training_concepts, :importance_order, :integer

    add_check_constraint :training_concepts,
      "kind IS NULL OR kind IN ('topic', 'strategic_maxim', 'measurable_dimension', 'phenomenological', 'technique', 'system')",
      name: "training_concepts_kind_check",
      validate: false

    # Partial unique index: nur nicht-null keys werden eindeutig erzwungen.
    add_index :training_concepts, :key,
              unique: true,
              algorithm: :concurrently,
              where: "key IS NOT NULL",
              name: "index_training_concepts_on_key"
  end
end
