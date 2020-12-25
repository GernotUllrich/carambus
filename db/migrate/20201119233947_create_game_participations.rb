class CreateGameParticipations < ActiveRecord::Migration[6.0]
  def change
    create_table :game_participations do |t|
      t.integer :game_id
      t.integer :player_id
      t.string :role
      t.text :data
      t.integer :points
      t.integer :result
      t.integer :innings
      t.float :gd
      t.integer :hs
      t.string :gname

      t.timestamps
    end
  end
end
