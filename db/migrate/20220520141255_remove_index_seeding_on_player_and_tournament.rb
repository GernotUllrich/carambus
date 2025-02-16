class RemoveIndexSeedingOnPlayerAndTournament < ActiveRecord::Migration[6.1]
  def change
    remove_index :seedings, ["player_id", "tournament_id"]
  end
end
