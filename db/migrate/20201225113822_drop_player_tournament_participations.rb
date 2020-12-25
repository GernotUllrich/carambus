class DropPlayerTournamentParticipations < ActiveRecord::Migration[6.0]
  def change
    drop_table :player_tournament_participations
  end
end
