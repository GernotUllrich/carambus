class AddHeaterToTableLocals < ActiveRecord::Migration[7.1]
  def change
    add_column :table_locals, :heater, :boolean
  end
end
