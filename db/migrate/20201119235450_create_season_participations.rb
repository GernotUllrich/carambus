class CreateSeasonParticipations < ActiveRecord::Migration[6.0]
  def change
    create_table :season_participations do |t|
      t.integer :player_id
      t.integer :season_id
      t.text :data
      t.integer :club_id

      t.timestamps
    end
  end
end
