class AddPlayerIdToSeasonParticipations < ActiveRecord::Migration
  def change
    add_column :season_participations, :club_id, :integer
  end
end
