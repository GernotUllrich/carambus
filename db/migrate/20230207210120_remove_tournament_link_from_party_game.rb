class RemoveTournamentLinkFromPartyGame < ActiveRecord::Migration[7.0]
  def change
    remove_column :party_games, :tournament_id, :integer
  end
end
