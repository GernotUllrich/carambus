class AddParentIdToTrainingExamples < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    add_column :training_examples, :parent_id, :integer
    add_index :training_examples, :parent_id, algorithm: :concurrently
    add_foreign_key :training_examples, :training_examples, column: :parent_id, validate: false
  end
end
