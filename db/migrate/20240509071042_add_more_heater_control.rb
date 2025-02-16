class AddMoreHeaterControl < ActiveRecord::Migration[7.1]
  def change
    add_column :tables, :manual_heater_on_at, :datetime
    add_column :tables, :manual_heater_off_at, :datetime
    add_column :table_locals, :manual_heater_on_at, :datetime
    add_column :table_locals, :manual_heater_off_at, :datetime
  end
end
