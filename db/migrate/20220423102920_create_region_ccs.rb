class CreateRegionCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :region_ccs do |t|
      t.integer :cc_id
      t.string :context
      t.integer :region_id
      t.string :shortname
      t.string :name

      t.timestamps
    end
  end
end
