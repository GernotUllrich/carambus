class AddRemarksToGameParticipations < ActiveRecord::Migration
  def change
    add_column :game_participations, :remarks, :text
  end
end
