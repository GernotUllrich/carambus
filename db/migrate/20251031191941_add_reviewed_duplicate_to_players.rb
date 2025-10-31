class AddReviewedDuplicateToPlayers < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    add_column :players, :reviewed_duplicate, :boolean, default: false, null: false unless column_exists?(:players, :reviewed_duplicate)
    add_index :players, :reviewed_duplicate, algorithm: :concurrently unless index_exists?(:players, :reviewed_duplicate)
  end
end
