class AddPlayerClassToDisciplineTournamentPlans < ActiveRecord::Migration
  def change
    add_column :discipline_tournament_plans, :player_class, :string
  end
end
