class AddLeagueToTournament < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :league_id, :integer
  end
end
