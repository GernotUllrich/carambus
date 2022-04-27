class CreatePartyCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :party_ccs do |t|
      t.integer :cc_id
      t.integer :league_cc_id
      t.integer :party_id
      t.integer :league_team_a_cc_id
      t.integer :league_team_b_cc_id
      t.integer :league_team_host_cc_id
      t.integer :day_seqno
      t.text :remarks
      t.text :data

      t.timestamps
    end
  end
end
