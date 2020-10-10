class AddMgmtStatusToTournaments < ActiveRecord::Migration
  def change
    add_column :tournaments, :mgmt_status, :string, null: false, default: ""
  end
end
