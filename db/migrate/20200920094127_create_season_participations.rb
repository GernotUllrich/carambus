class CreateSeasonParticipations < ActiveRecord::Migration
  def change
    create_table :season_participations do |t|
      t.integer :player_id
      t.integer :season_id
      t.text :remarks

      t.timestamps null: false
    end
  end
end
