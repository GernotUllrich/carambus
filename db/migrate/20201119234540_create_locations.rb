class CreateLocations < ActiveRecord::Migration[6.0]
  def change
    create_table :locations do |t|
      t.integer :club_id
      t.text :address
      t.text :data
      t.string :name

      t.timestamps
    end
  end
end
