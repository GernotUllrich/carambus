class AddTableAssociationToTableMonitors < ActiveRecord::Migration[6.0]
  def change
    add_column :table_monitors, :table_id, :integer, null: false, unique: true
  end
end
