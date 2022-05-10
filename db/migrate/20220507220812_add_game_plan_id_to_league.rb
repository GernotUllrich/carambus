class AddGamePlanIdToLeague < ActiveRecord::Migration[6.1]
  def change
    add_column :league_ccs, :game_plan_cc_id, :integer
  end
end
