class CreatePartyMonitors < ActiveRecord::Migration[7.0]
  def change
    create_table :party_monitors do |t|
      t.integer :party_id
      t.string :state
      t.text :data
      t.datetime :started_at
      t.datetime :ended_at

      t.timestamps
    end
  end
end
