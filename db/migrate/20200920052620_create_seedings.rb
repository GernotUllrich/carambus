class CreateSeedings < ActiveRecord::Migration
  def change
    create_table :seedings do |t|
      t.integer :player_id
      t.integer :tournament_id
      t.string :status
      t.integer :position
      t.text :remarks

      t.timestamps null: false
    end
  end
end
