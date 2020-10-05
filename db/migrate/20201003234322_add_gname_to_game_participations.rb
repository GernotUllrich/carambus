class AddGnameToGameParticipations < ActiveRecord::Migration
  def change
    add_column :game_participations, :gname, :string
  end
end
