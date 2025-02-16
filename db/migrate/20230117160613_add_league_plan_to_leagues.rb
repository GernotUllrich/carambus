class AddLeaguePlanToLeagues < ActiveRecord::Migration[7.0]
  def change
    add_column :leagues, :league_plan_id, :integer
  end
end
