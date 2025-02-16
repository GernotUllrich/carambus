class AddHeaterNoAutoToTables < ActiveRecord::Migration[7.1]
  def change
    add_column :tables, :heater_auto, :boolean
  end
end
