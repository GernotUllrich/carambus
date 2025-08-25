class AddBaIdToSeasonParticipations < ActiveRecord::Migration[7.0]
  def change
    add_column :season_participations, :ba_id, :string
  end
end
