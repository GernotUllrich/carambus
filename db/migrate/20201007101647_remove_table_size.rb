class RemoveTableSize < ActiveRecord::Migration
  def change
    remove_column :disciplines, :table_size
  end
end
