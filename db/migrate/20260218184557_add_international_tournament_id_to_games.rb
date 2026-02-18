class AddInternationalTournamentIdToGames < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    add_reference :games, :international_tournament, index: { algorithm: :concurrently }
    add_column :games, :type, :string
    add_index :games, :type, algorithm: :concurrently
  end
end
