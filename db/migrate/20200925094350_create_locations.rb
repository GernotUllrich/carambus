class CreateLocations < ActiveRecord::Migration
  def change
    create_table :locations do |t|
      t.integer :club_id
      t.text :address
      t.text :data

      t.timestamps null: false
    end
  end
end
