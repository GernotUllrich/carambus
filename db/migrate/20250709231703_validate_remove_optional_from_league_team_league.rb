class ValidateRemoveOptionalFromLeagueTeamLeague < ActiveRecord::Migration[7.2]
  def change
    validate_check_constraint :league_teams, name: "league_teams_league_id_null"
    change_column_null :league_teams, :league_id, false
    remove_check_constraint :league_teams, name: "league_teams_league_id_null"
  end
end
