class ChangeIndexCcIdOnTournamentCcs < ActiveRecord::Migration[7.0]
  def change
    remove_index :tournament_ccs, ["cc_id"], unique: true
    add_index :tournament_ccs, ["cc_id", "context"], unique: true
  end
end
