class AddNewUniqueIndexToParties < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :parties, [:league_id, :day_seqno, :league_team_a_id, :league_team_b_id], unique: true, name: "index_parties_on_league_and_teams", algorithm: :concurrently
  end
end
