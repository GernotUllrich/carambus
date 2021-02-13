class AlterMd5InLocations < ActiveRecord::Migration[6.0]
  def change
    change_column_null :locations, :md5, false
    remove_index :locations, column: :md5
    add_index :locations, :md5, unique: true
  end
end
