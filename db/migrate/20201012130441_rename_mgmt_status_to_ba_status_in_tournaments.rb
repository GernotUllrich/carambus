class RenameMgmtStatusToBaStatusInTournaments < ActiveRecord::Migration
  def change
    rename_column :tournaments, :mgmt_status, :ba_state
    add_column :tournaments, :state, :string, null: false, default: "new_tournament"
  end
end
