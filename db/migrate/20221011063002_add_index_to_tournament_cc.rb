class AddIndexToTournamentCc < ActiveRecord::Migration[6.1]
  def change
    add_index :tournament_ccs, ["cc_id"], unique: true
    add_index :tournament_ccs, ["tournament_id"], unique: true
  end
end
