class CreateClubs < ActiveRecord::Migration[6.0]
  def change
    create_table :clubs do |t|
      t.integer :ba_id
      t.integer :region_id
      t.string :name
      t.string :shortname
      t.text :address
      t.string :homepage
      t.string :email
      t.text :priceinfo
      t.string :logo
      t.string :status
      t.string :founded
      t.string :dbu_entry

      t.timestamps
    end
  end
end
