class RenameTemplatesToTournamentPlans < ActiveRecord::Migration
  def change
    rename_table :templates, :tournament_plans
  end
end
