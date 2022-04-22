class AddNoShowToParty < ActiveRecord::Migration[6.1]
  def change
    add_column :parties, :no_show_team_id, :integer
    add_column :parties, :section, :string
  end
end
