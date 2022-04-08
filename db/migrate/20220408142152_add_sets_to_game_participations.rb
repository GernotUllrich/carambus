class AddSetsToGameParticipations < ActiveRecord::Migration[6.0]
  def change
    add_column :game_participations, :sets, :integer
  end
end
