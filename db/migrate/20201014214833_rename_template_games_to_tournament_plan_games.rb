class RenameTemplateGamesToTournamentPlanGames < ActiveRecord::Migration
  def change
    rename_column :template_games, :template_id, :tournament_plan_id
    rename_column :tournaments, :template_id, :tournament_plan_id
    rename_column :discipline_tournament_plans, :template_id, :tournament_plan_id
    rename_table :template_games, :tournament_plan_games
  end
end