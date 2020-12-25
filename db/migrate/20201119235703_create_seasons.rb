class CreateSeasons < ActiveRecord::Migration[6.0]
  def change
    create_table :seasons do |t|
      t.integer :ba_id
      t.string :name
      t.text :data

      t.timestamps
    end
  end
end
