class AddLeagueTeamIdToSeedings < ActiveRecord::Migration[6.0]
  def change
    add_column :seedings, :league_team_id, :integer
  end
end
