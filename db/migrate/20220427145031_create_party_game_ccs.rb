class CreatePartyGameCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :party_game_ccs do |t|
      t.integer :cc_id
      t.integer :seqno
      t.integer :player_a_id
      t.integer :player_b_id
      t.text :data
      t.string :name
      t.integer :discipline_id

      t.timestamps
    end
  end
end
