class AddNrepeatsToTournamentPlan < ActiveRecord::Migration
  def change
    add_column :tournament_plans, :nrepeats, :integer, null: false, default: 1
  end
end
