class RenameDisciplineTemplatesToDisciplineTournamentPlans < ActiveRecord::Migration
  def change
    rename_table :discipline_tournament_plans, :discipline_tournament_plans
  end
end
