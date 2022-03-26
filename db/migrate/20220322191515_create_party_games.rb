class CreatePartyGames < ActiveRecord::Migration[6.0]
  def change
    create_table :party_games do |t|
      t.integer :party_id
      t.integer :seqno
      t.integer :player_a_id
      t.integer :player_b_id
      t.integer :tournament_id

      t.timestamps
    end
  end
end
