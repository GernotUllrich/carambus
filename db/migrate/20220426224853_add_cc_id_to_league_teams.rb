class AddCcIdToLeagueTeams < ActiveRecord::Migration[6.1]
  def change
    add_column :league_teams, :cc_id, :integer
  end
end
