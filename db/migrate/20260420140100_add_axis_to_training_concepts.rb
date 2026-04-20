class AddAxisToTrainingConcepts < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    # v0.8 Tier 1: Gretillats 4er-Spine ({technique, conception, psychology, training}).
    # Default 'conception' — dort sitzt der Großteil der Serienspiel-Literatur.
    add_column :training_concepts, :axis, :string, default: "conception", null: false

    add_check_constraint :training_concepts,
      "axis IN ('technique', 'conception', 'psychology', 'training')",
      name: "training_concepts_axis_check", validate: false

    add_index :training_concepts, :axis, algorithm: :concurrently
  end
end
