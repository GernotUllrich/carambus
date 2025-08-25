class RemoveLeaguePlanFromLeagues < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_column :leagues, :league_plan_id, :integer
    end
  end
end
