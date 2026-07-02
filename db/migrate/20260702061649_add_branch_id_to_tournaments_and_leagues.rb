class AddBranchIdToTournamentsAndLeagues < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    # Derived FK-Dimension (analog region_id): nullable, kein FK-Constraint (Discipline global).
    add_column :tournaments, :branch_id, :integer unless column_exists?(:tournaments, :branch_id)
    add_column :leagues, :branch_id, :integer unless column_exists?(:leagues, :branch_id)

    add_index :tournaments, :branch_id, algorithm: :concurrently unless index_exists?(:tournaments, :branch_id)
    add_index :leagues, :branch_id, algorithm: :concurrently unless index_exists?(:leagues, :branch_id)
  end
end
