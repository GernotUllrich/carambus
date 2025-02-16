class CreateSeedings < ActiveRecord::Migration[6.0]
  def change
    create_table :seedings do |t|
      t.integer :player_id
      t.integer :tournament_id
      t.string :ba_state
      t.integer :position
      t.text :data
      t.string :state
      t.integer :balls_goal
      t.integer :playing_discipline_id

      t.timestamps
    end
  end
end
