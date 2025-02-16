class AddGamePlanToLeagues < ActiveRecord::Migration[7.0]
  def change
    add_column :leagues, :game_plan_id, :integer
  end
end
