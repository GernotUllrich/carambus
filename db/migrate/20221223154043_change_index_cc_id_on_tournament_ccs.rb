class ChangeIndexCcIdOnTournamentCcs < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      remove_index :tournament_ccs, :cc_id
      add_index :tournament_ccs, :cc_id, algorithm: :concurrently
    end
  end
end
