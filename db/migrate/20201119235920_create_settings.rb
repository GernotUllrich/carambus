class CreateSettings < ActiveRecord::Migration[6.0]
  def change
    create_table :settings do |t|
      t.text :data
      t.string :state
      t.integer :region_id
      t.integer :club_id
      t.integer :tournament_id

      t.timestamps
    end
  end
end
