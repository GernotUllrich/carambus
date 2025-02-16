class AddCcId2ToLeagueTeams < ActiveRecord::Migration[7.0]
  def change
    add_column :league_teams, :cc_id, :integer
  end
end
