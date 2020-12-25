class CreatePlayers < ActiveRecord::Migration[6.0]
  def change
    create_table :players do |t|
      t.integer :ba_id
      t.integer :club_id
      t.string :lastname
      t.string :firstname
      t.string :title

      t.timestamps
    end
  end
end
