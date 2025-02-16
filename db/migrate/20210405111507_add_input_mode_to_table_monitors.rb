class AddInputModeToTableMonitors < ActiveRecord::Migration[6.0]
  def change
    add_column :table_monitors, :panel_state, :string, default: "pointer_mode", null: false
    add_column :table_monitors, :current_element, :string, default: "pointer_mode", null: false
  end
end
