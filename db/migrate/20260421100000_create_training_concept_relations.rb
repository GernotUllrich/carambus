class CreateTrainingConceptRelations < ActiveRecord::Migration[7.2]
  # v0.9 Phase C: self-referentielle Join-Tabelle für Concept-Beziehungen.
  # Ersetzt die gelöschte concept_principles-Tabelle (Phase A) als
  # allgemeinere, typisierte Concept↔Concept-Relation. teaches/applies/
  # exemplifies kommen aus dem alten concept_principles-Vokabular und
  # werden ergänzt durch specializes (Hierarchie) und parallels (gleich-
  # rangige verwandte Topics).
  def change
    create_table :training_concept_relations do |t|
      t.references :source_concept,
                   null: false,
                   foreign_key: { to_table: :training_concepts }
      t.references :target_concept,
                   null: false,
                   foreign_key: { to_table: :training_concepts }
      t.string     :relation, null: false
      t.text       :notes

      t.timestamps
    end

    add_index :training_concept_relations,
              [:source_concept_id, :target_concept_id, :relation],
              unique: true, name: "idx_concept_relation_unique"

    add_check_constraint :training_concept_relations,
      "relation IN ('teaches','applies','exemplifies','specializes','parallels')",
      name: "training_concept_relations_relation_check"

    # Selbstschleifen (A → A) sind immer semantisch sinnlos.
    add_check_constraint :training_concept_relations,
      "source_concept_id <> target_concept_id",
      name: "training_concept_relations_no_self_loop"
  end
end
