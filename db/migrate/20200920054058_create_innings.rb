class CreateInnings < ActiveRecord::Migration
  def change
    create_table :innings do |t|
      t.integer :game_id
      t.integer :sequence_number
      t.string :player_a_count
      t.string :player_b_count
      t.string :player_c_count
      t.string :player_d_count
      t.text :remarks

      t.timestamps null: false
    end
  end
end
