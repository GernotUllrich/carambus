class AddUniqueIndexToGames < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    unless index_exists?(:games, [:tournament_id, :gname, :seqno])
      add_index :games, [:tournament_id, :gname, :seqno], unique: true, algorithm: :concurrently
    end
  end
end
