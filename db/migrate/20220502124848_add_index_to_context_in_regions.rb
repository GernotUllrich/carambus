class AddIndexToContextInRegions < ActiveRecord::Migration[6.1]
  def change
    add_index :region_ccs, [:context], unique: true
  end
end
