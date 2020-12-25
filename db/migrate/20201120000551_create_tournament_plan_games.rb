class CreateTournamentPlanGames < ActiveRecord::Migration[6.0]
  def change
    create_table :tournament_plan_games do |t|
      t.string :name
      t.integer :tournament_plan_id
      t.text :data

      t.timestamps
    end
  end
end
