class CreateRegions < ActiveRecord::Migration[6.0]
  def change
    create_table :regions do |t|
      t.string :name
      t.string :shortname
      t.string :logo
      t.string :email
      t.text :address
      t.integer :country_id

      t.timestamps
    end
  end
end
