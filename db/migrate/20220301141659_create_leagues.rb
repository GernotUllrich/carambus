class CreateLeagues < ActiveRecord::Migration[6.0]
  def change
    create_table :leagues do |t|
      t.string :name
      t.date :registration_until
      t.string :organizer_type
      t.integer :organizer_id
      t.integer :season_id
      t.integer :ba_id
      t.integer :ba_id2
      t.integer :discipline_id

      t.timestamps
    end
  end
end
