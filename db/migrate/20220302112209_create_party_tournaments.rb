class CreatePartyTournaments < ActiveRecord::Migration[6.0]
  def change
    create_table :party_tournaments do |t|
      t.integer :party_id
      t.integer :tournament_id
      t.integer :position

      t.timestamps
    end
  end
end
