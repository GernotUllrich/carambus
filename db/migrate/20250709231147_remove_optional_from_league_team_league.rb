class RemoveOptionalFromLeagueTeamLeague < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :league_teams, "league_id IS NOT NULL", name: "league_teams_league_id_null", validate: false
  end
end


