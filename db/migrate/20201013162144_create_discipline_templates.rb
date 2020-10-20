class CreateDisciplineTournamentPlans < ActiveRecord::Migration
  def change
    create_table :discipline_tournament_plans do |t|
      t.integer :discipline_id
      t.integer :tournament_plan_id
      t.integer :points
      t.integer :innings
      t.integer :players

      t.timestamps null: false
    end
  end
end
