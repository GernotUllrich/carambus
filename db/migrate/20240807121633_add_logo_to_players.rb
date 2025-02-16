class AddLogoToPlayers < ActiveRecord::Migration[7.2]
  def change
    add_column :players, :logo, :string
  end
end
