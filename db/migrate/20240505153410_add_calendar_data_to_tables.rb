class AddCalendarDataToTables < ActiveRecord::Migration[7.1]
  def change
    add_column :tables, :event_id, :string
    add_column :tables, :event_summary, :string
    add_column :tables, :event_creator, :string
    add_column :tables, :event_start, :datetime
    add_column :tables, :event_end, :datetime
    add_column :tables, :heater_on_reason, :string
    add_column :tables, :heater_off_reason, :string
    add_column :tables, :heater_switched_on_at, :datetime
    add_column :tables, :heater_switched_off_at, :datetime
    add_column :table_locals, :event_id, :string
    add_column :table_locals, :event_summary, :string
    add_column :table_locals, :event_creator, :string
    add_column :table_locals, :event_start, :datetime
    add_column :table_locals, :event_end, :datetime
    add_column :table_locals, :heater_on_reason, :string
    add_column :table_locals, :heater_off_reason, :string
    add_column :table_locals, :heater_switched_on_at, :datetime
    add_column :table_locals, :heater_switched_off_at, :datetime
  end
end
