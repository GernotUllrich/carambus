class AddLastBaSyncToTournaments < ActiveRecord::Migration
  def change
    add_column :tournaments, :last_ba_sync_date, :datetime
  end
end
