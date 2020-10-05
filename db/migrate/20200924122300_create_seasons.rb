class CreateSeasons < ActiveRecord::Migration
  def change
    create_table :seasons do |t|
      t.integer :ba_id
      t.string :name
      t.text :data

      t.timestamps null: false
    end
  end
end
