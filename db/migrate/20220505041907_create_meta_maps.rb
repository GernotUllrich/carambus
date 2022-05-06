class CreateMetaMaps < ActiveRecord::Migration[6.1]
  def change
    create_table :meta_maps do |t|
      t.string :class_ba
      t.string :class_cc
      t.string :ba_base_url
      t.string :cc_base_url
      t.text :data

      t.timestamps
    end
  end
end
