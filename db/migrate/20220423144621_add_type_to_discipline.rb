class AddTypeToDiscipline < ActiveRecord::Migration[6.1]
  def change
    add_column :disciplines, :type, :string
  end
end
