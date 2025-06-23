class DropRegionTagging < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    drop_table :region_taggings
  end
end
