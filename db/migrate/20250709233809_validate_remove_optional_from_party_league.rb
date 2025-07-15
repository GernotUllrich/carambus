class ValidateRemoveOptionalFromPartyLeague < ActiveRecord::Migration[7.2]
  def change
    validate_check_constraint :parties, name: "parties_league_id_null"
    change_column_null :parties, :league_id, false
    remove_check_constraint :parties, name: "parties_league_id_null"
  end
end
