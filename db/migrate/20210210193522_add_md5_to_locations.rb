class AddMd5ToLocations < ActiveRecord::Migration[6.0]
  def change
    add_column :locations, :md5, :string
    add_index :locations, :md5
  end
end
