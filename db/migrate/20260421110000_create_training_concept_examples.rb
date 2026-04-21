class CreateTrainingConceptExamples < ActiveRecord::Migration[7.2]
  # v0.9 Phase D: M2M Join TrainingConcept ↔ TrainingExample mit Gewichtung.
  # Ersetzt die bisherige 1:N-Beziehung (training_examples.training_concept_id).
  # Eine Übung kann jetzt mehrere Konzepte bedienen; die Gewichtung (weight
  # 1-5) sagt, wie paradigmatisch sie für das jeweilige Konzept ist.
  # sequence_number wandert von training_examples ins Join, weil die
  # Reihenfolge konzept-abhängig ist (dieselbe Übung kann in Konzept X
  # früher und in Konzept Y später kommen).
  def change
    create_table :training_concept_examples do |t|
      t.references :training_concept, null: false, foreign_key: true
      t.references :training_example, null: false, foreign_key: true
      t.integer    :weight,           null: false, default: 3
      t.string     :role
      t.integer    :sequence_number
      t.text       :notes

      t.timestamps
    end

    add_index :training_concept_examples,
              [:training_concept_id, :training_example_id],
              unique: true, name: "idx_concept_example_unique"

    add_index :training_concept_examples,
              [:training_concept_id, :sequence_number],
              unique: true,
              where: "sequence_number IS NOT NULL",
              name: "idx_concept_example_sequence_unique"

    add_check_constraint :training_concept_examples,
      "weight BETWEEN 1 AND 5",
      name: "training_concept_examples_weight_check"

    add_check_constraint :training_concept_examples,
      "role IS NULL OR role IN ('illustrates','counter_example')",
      name: "training_concept_examples_role_check"

    # Daten-Migration: bestehende (training_concept_id, sequence_number)
    # von training_examples ins Join kopieren. Weight=5 für die bisher
    # einzige Concept-Zuordnung — sie waren per FK primär verknüpft.
    reversible do |dir|
      dir.up do
        safety_assured do
          execute <<~SQL
            INSERT INTO training_concept_examples
              (training_concept_id, training_example_id, weight, sequence_number,
               created_at, updated_at)
            SELECT training_concept_id, id, 5, sequence_number,
                   NOW(), NOW()
            FROM training_examples
            WHERE training_concept_id IS NOT NULL;
          SQL
        end
      end
    end
  end
end
