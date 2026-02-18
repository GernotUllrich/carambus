class AddUmbFieldsToPlayers < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    add_column :players, :umb_player_id, :integer
    add_column :players, :nationality, :string, limit: 2  # ISO 3166-1 alpha-2
    
    add_index :players, :umb_player_id, algorithm: :concurrently
    add_index :players, :nationality, algorithm: :concurrently
  end
end
