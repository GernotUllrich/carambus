class CreateGames < ActiveRecord::Migration
  def change
    create_table :games do |t|
      t.integer :template_game_id
      t.integer :tournament_id
      t.text :roles
      t.text :remarks

      t.timestamps null: false
    end
  end
end
