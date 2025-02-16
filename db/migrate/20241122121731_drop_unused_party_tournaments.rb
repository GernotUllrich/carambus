class DropUnusedPartyTournaments < ActiveRecord::Migration[7.2]
  def up
    drop_table :party_tournaments, if_exists: true
  end

  def down
    # Optional: Recreate the table if you want a rollback option
    create_table :party_tournaments do |t|
      # Add columns that were in the table
      t.integer "party_id"
      t.integer "tournament_id"
      t.integer "position"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end
  end
end
