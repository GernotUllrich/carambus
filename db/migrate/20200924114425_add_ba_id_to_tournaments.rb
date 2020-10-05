class AddBaIdToTournaments < ActiveRecord::Migration
  def change
    add_column :tournaments, :ba_id, :integer
    add_column :tournaments, :season_id,:integer
    add_column :tournaments, :region_id, :integer
    add_column :tournaments, :end_date, :datetime
  end
end
