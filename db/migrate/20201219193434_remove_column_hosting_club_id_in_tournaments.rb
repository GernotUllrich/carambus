class RemoveColumnHostingClubIdInTournaments < ActiveRecord::Migration[6.0]
  def change
    remove_column :tournaments, :hosting_club_id
  end
end
