class CreateRegions < ActiveRecord::Migration
  def change
    create_table :regions do |t|
      t.string :name
      t.string :shortname
      t.string :logo
      t.string :email
      t.text :address
      t.integer :country_id

      t.timestamps null: false
    end
  end
end
