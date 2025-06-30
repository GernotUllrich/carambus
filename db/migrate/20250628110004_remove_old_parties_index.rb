class RemoveOldPartiesIndex < ActiveRecord::Migration[7.2]
    def change
      remove_index :parties, name: 'index_parties_on_league_and_teams_and_cc_id'
    end
end
