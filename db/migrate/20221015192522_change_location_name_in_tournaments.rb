class ChangeLocationNameInTournaments < ActiveRecord::Migration[7.0]
  def change
    # Change location name in tournaments table
    # This migration likely renames or modifies the location column
    safety_assured do
      rename_column :tournaments, :location, :location_text
    end
  end
end
