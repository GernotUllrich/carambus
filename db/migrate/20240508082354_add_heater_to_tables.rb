class AddHeaterToTables < ActiveRecord::Migration[7.1]
  def change
    add_column :tables, :heater, :boolean
  end
end
