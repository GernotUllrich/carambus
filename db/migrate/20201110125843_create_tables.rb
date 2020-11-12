class CreateTables < ActiveRecord::Migration[5.2]
  def change
    create_table :tables do |t|
      t.integer :location_id
      t.integer :table_kind_id
      t.string :name
      t.text :data

      t.timestamps
    end
  end
end
