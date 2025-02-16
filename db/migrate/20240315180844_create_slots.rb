class CreateSlots < ActiveRecord::Migration[7.0]
  def change
    create_table :slots do |t|
      t.integer :dayofweek
      t.integer :hourofday_start
      t.integer :minuteofhour_start
      t.integer :hourofday_end
      t.integer :minuteofhour_end
      t.datetime :next_start
      t.datetime :next_end
      t.integer :table_id
      t.boolean :recurring

      t.timestamps
    end
  end
end
