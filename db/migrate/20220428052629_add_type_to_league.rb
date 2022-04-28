class AddTypeToLeague < ActiveRecord::Migration[6.1]
  def change
    add_column :leagues, :type, :string
  end
end
