class CreateDisciplineTournamentPlans < ActiveRecord::Migration[6.0]
  def change
    create_table :discipline_tournament_plans do |t|
      t.integer :discipline_id
      t.integer :tournament_plan_id
      t.integer :points
      t.integer :innings
      t.integer :players
      t.string :player_class

      t.timestamps
    end
  end
end
