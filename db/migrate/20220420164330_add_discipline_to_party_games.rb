class AddDisciplineToPartyGames < ActiveRecord::Migration[6.1]
  def change
    add_column :party_games, :discipline_id, :integer
  end
end
