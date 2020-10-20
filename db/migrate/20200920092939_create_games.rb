class CreateGames < ActiveRecord::Migration
  def change
    create_table :games do |t|
      t.integer :tournament_plan_game_id
      t.integer :tournament_id
      t.text :roles
      t.text :remarks

      t.timestamps null: false
    end
  end
end
