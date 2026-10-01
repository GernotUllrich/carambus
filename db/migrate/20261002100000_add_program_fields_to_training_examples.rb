# frozen_string_literal: true

class AddProgramFieldsToTrainingExamples < ActiveRecord::Migration[7.2]
  # Trainingsprogramme (Handoff Claudia 2026-10-02, Pilot: Weingartners
  # Pflichtstossprogramm). Der Programmbaum ist der bestehende TrainingExample-
  # Baum (Programm -> Gruppe -> Figur ueber parent_id); neu sind:
  #
  #   points          Wertpunkte einer Figur (Weingartner 4-11); bei Gruppe/Programm nil
  #   contre_allowed  Kennzeichen (C): Contre zaehlt nicht als Fehler; nil = Quelle sagt nichts
  #   sequence_number Reihenfolge unter demselben Elternknoten
  #
  # Die Tabelle hat eine einstellige Zeilenzahl; Check und Index im selben Schritt
  # sind unkritisch, deshalb safety_assured statt add/validate bzw. concurrently
  # (wie 20260902232138).
  def change
    add_column :training_examples, :points, :integer
    add_column :training_examples, :contre_allowed, :boolean
    add_column :training_examples, :sequence_number, :integer

    safety_assured do
      add_check_constraint :training_examples, "points IS NULL OR points > 0",
        name: "training_examples_points_check"
      add_check_constraint :training_examples, "sequence_number IS NULL OR sequence_number > 0",
        name: "training_examples_sequence_number_check"
      add_index :training_examples, [:parent_id, :sequence_number], unique: true,
        where: "sequence_number IS NOT NULL", name: "idx_training_examples_parent_sequence_unique"
    end
  end
end
