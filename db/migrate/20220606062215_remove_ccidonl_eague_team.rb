class RemoveCcidonlEagueTeam < ActiveRecord::Migration[6.1]
  def change
    remove_column :league_teams, :cc_id, :integer
  end
end
