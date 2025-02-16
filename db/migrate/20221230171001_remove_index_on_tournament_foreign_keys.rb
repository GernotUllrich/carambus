class RemoveIndexOnTournamentForeignKeys < ActiveRecord::Migration[7.0]
  def change
    # remove_index :tournaments,["title", "season_id", "region_id"]
    # remove_index :tournaments,["organizer_id", "organizer_type", "season_id", "title"]
  end
end
