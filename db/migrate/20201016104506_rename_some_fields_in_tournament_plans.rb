class RenameSomeFieldsInTournamentPlans < ActiveRecord::Migration
  def change
    rename_column :tournament_plans, :groups_text_round1, :data_round1
    rename_column :tournament_plans, :groups_text_round2, :data_round2
    rename_column :tournament_plans, :groups_text_round3, :data_round3
    rename_column :tournament_plans, :groups_text_round4, :data_round4
    rename_column :tournament_plans, :groups_text_round5, :data_round5
    rename_column :tournament_plans, :groups_text_round6, :data_round6
    rename_column :tournament_plans, :groups_text_round7, :data_round7
    rename_column :tournament_plans, :finals_text_round1, :data_round8
    rename_column :tournament_plans, :finals_text_round2, :data_round9
    rename_column :tournament_plans, :finals_text_round3, :data_round10
    rename_column :tournament_plans, :finals_text_round4, :data_round11
  end
end
