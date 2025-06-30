class AddUniqueIndexToParties < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change

    unless index_exists?(:parties, [:league_id, :day_seqno, :league_team_a_id, :league_team_b_id, :cc_id])
      add_index :parties, [:league_id, :day_seqno, :league_team_a_id, :league_team_b_id, :cc_id], unique: true, name: 'index_parties_on_league_and_teams_and_cc_id', algorithm: :concurrently
    end
  end
end
