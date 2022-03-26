class CreateParties < ActiveRecord::Migration[6.0]
  def change
    create_table :parties do |t|
      t.datetime :date
      t.integer :league_id
      t.text :remarks
      t.integer :league_team_a_id
      t.integer :league_team_b_id
      t.integer :ba_id
      t.integer :day_seqno
      t.text :data
      t.integer :host_league_team_id

      t.timestamps
    end
  end
end
