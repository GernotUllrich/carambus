class CreatePlayerTournamentParticipations < ActiveRecord::Migration
  def change
    create_table :player_tournament_participations do |t|
      t.integer :player_id
      t.integer :tournament_id
      t.text :data

      t.timestamps null: false
    end
  end
end
