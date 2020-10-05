class CreatePlayers < ActiveRecord::Migration
  def change
    create_table :players do |t|
      t.integer :ba_id
      t.integer :club_id
      t.string :lastname
      t.string :firstname
      t.string :title

      t.timestamps null: false
    end
  end
end
