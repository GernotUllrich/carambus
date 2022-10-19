class AddTournamentToTournamentCc < ActiveRecord::Migration[6.1]
  def change
    add_column :tournament_ccs, :tournament_id, :integer
  end
end
