class AddDataToLeagueTeams < ActiveRecord::Migration[7.2]
  def change
    add_column :league_teams, :data, :text
  end
end
