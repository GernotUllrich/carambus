class CreateGameParticipations < ActiveRecord::Migration
  def change
    create_table :game_participations do |t|
      t.integer :game_id
      t.integer :player_id
      t.string :role

      t.timestamps null: false
    end
  end
end
