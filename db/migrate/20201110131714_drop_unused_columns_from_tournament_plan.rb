class DropUnusedColumnsFromTournamentPlan < ActiveRecord::Migration[5.2]
  def change
    remove_column :tournament_plans, :data_round1
    remove_column :tournament_plans, :data_round2
    remove_column :tournament_plans, :data_round3
    remove_column :tournament_plans, :data_round4
    remove_column :tournament_plans, :data_round5
    remove_column :tournament_plans, :data_round6
    remove_column :tournament_plans, :data_round7
    remove_column :tournament_plans, :data_round8
    remove_column :tournament_plans, :data_round9
    remove_column :tournament_plans, :data_round10
    remove_column :tournament_plans, :data_round11
  end
end
