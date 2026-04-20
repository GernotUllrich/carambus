class ChangeLocationNameInTournaments < ActiveRecord::Migration[7.0]
  def change
    # Change location name in tournaments table
    # Only rename if the old column exists (idempotent for baseline)
    safety_assured do
      if column_exists?(:tournaments, :location) && !column_exists?(:tournaments, :location_text)
        rename_column :tournaments, :location, :location_text
      end
    end
  end
end
