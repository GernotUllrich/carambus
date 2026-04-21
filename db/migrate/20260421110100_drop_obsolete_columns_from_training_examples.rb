class DropObsoleteColumnsFromTrainingExamples < ActiveRecord::Migration[7.2]
  # v0.9 Phase D (Teil 2): nach dem Daten-Transfer ins Join können die
  # jetzt redundanten Spalten von training_examples entfernt werden.
  # training_concept_id wird durch die M2M ersetzt, sequence_number
  # lebt konzept-abhängig auf dem Join (Migration 110000).
  def change
    safety_assured do
      remove_foreign_key :training_examples, :training_concepts
      remove_index :training_examples, name: "index_training_examples_on_concept_and_sequence"
      remove_index :training_examples, name: "index_training_examples_on_training_concept_id"
      remove_column :training_examples, :training_concept_id, :bigint, null: false
      remove_column :training_examples, :sequence_number,     :integer, default: 1, null: false
    end
  end
end
