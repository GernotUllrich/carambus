class AddRoleToSeeding < ActiveRecord::Migration[7.0]
  def change
    add_column :seedings, :role, :string
  end
end
