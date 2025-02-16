class RemoveLeaguePlanFromLeagues < ActiveRecord::Migration[7.0]
  def change
    remove_column :leagues, :league_plan_id, :integer
  end
end
