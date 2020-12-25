class CreatePlayerTournamentParticipations < ActiveRecord::Migration[6.0]
  def change
    create_table :player_tournament_participations do |t|
      t.integer :player_id
      t.integer :tournament_id
      t.text :data

      t.timestamps
    end
  end
end
