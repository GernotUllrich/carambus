class AddUniqueIndexToGames < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    add_index :games, [:tournament_id, :gname, :seqno], unique: true, algorithm: :concurrently
  end
end
