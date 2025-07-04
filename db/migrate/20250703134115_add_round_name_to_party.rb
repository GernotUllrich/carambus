class AddRoundNameToParty < ActiveRecord::Migration[7.2]
  def change
    add_column :parties, :round_name, :string
  end
end
