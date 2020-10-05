class AddFieldsToGameParticipations < ActiveRecord::Migration
  def change
    add_column :game_participations, :points, :integer
    add_column :game_participations, :result, :integer
    add_column :game_participations, :innings, :integer
    add_column :game_participations, :gd, :float
    add_column :game_participations, :hs, :integer
  end
end
