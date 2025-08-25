class RemoveTournamentLinkFromPartyGame < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_column :party_games, :tournament_id, :integer
    end
  end
end
