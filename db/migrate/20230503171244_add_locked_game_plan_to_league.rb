class AddLockedGamePlanToLeague < ActiveRecord::Migration[7.0]
  def change
    add_column :leagues, :game_plan_locked, :boolean, null: false, default: false
  end
end
