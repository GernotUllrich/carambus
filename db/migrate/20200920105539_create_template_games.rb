class CreateTournamentPlanGames < ActiveRecord::Migration
  def change
    create_table :tournament_plan_games do |t|
      t.string :name
      t.integer :tournament_plan_id
      t.text :remarks

      t.timestamps null: false
    end
  end
end
