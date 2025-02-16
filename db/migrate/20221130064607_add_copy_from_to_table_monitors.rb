class AddCopyFromToTableMonitors < ActiveRecord::Migration[7.0]
  def change
    add_column :table_monitors, :copy_from, :integer
  end
end
