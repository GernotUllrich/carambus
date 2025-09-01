class AddUniqueIndexToGames < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    unless index_exists?(:games, [:tournament_id, :gname, :seqno])
      # Clean up duplicate records before creating the unique index
      # Keep the record with the highest id (most recent) for each duplicate
      execute <<-SQL
        DELETE FROM games 
        WHERE id NOT IN (
          SELECT DISTINCT ON (tournament_id, gname, seqno) id 
          FROM games 
          ORDER BY tournament_id, gname, seqno, id DESC
        );
      SQL
      
      add_index :games, [:tournament_id, :gname, :seqno], unique: true, algorithm: :concurrently
    end
  end
end
