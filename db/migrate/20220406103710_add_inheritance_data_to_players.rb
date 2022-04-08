class AddInheritanceDataToPlayers < ActiveRecord::Migration[6.0]
  def change
    add_column :players, :type, :string
    add_column :players, :data, :text
    add_column :players, :tournament_id, :integer
  end
end
