class AddDataToPartyGame < ActiveRecord::Migration[6.0]
  def change
    add_column :party_games, :data, :text
    add_column :party_games, :name, :string
  end
end
