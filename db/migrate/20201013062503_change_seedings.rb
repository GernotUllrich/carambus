class ChangeSeedings < ActiveRecord::Migration
  def change
    rename_column :seedings, :status, :ba_state
    add_column :seedings, :state, :string, default: "registered", null: false
  end
end
