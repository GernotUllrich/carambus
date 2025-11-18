class AddHardwareTypeToTableLocals < ActiveRecord::Migration[7.2]
  def change
    add_column :table_locals, :hardware_type, :string
  end
end
