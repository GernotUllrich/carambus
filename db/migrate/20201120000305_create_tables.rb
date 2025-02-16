class CreateTables < ActiveRecord::Migration[6.0]
  def change
    create_table :tables do |t|
      t.integer :location_id
      t.integer :table_kind_id
      t.string :name
      t.text :data
      t.string :ip_address

      t.timestamps
    end
  end
end
