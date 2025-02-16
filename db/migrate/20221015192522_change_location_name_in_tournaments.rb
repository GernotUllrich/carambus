class ChangeLocationNameInTournaments < ActiveRecord::Migration[6.1]
  def change
    rename_column :tournaments, :location, :location_text
  end
end
