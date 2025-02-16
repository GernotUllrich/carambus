class AddTournamentTypeToGames < ActiveRecord::Migration[7.0]
  def change
    add_column :games, :tournament_type, :string
    Game.where.not(tournament_id: nil).update_all(tournament_type: "Tournament")
  end
end
