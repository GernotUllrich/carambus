class RemoveOptionalFromPartyLeague < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :parties, "league_id IS NOT NULL", name: "parties_league_id_null", validate: false
  end
end
