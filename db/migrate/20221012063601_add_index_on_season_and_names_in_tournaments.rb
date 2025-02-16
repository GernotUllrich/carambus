class AddIndexOnSeasonAndNamesInTournaments < ActiveRecord::Migration[6.1]
  def change
    # add_index :tournaments, ["organizer_id", "organizer_type", "season_id", "title"], name: "tournaments_title_index", unique: true
  end
end
