class AddBaIdToSeasonParticipations < ActiveRecord::Migration[7.0]
  def change
    add_column :season_participations, :ba_id, :integer
    # SeasonParticipation.all.each do |sp|
    #   if sp.player.present?
    #     sp.update(ba_id: sp.player.ba_id)
    #   else
    #     sp.destroy
    #     next
    #   end
    #   unless sp.club.present?
    #     sp.destroy
    #     next
    #   end
    # end
  end
end
