class AddSourceToLeagues < ActiveRecord::Migration[7.0]
  def change
    add_column :leagues, :source_url, :string
    add_column :leagues, :sync_date, :datetime

    add_column :parties, :source_url, :string
    add_column :parties, :sync_date, :datetime

    add_column :tournaments, :source_url, :string

    # Use safety_assured for the rename operation
    safety_assured do
    rename_column :tournaments, :last_ba_sync_date, :sync_date
    end

    add_column :players, :source_url, :string
    add_column :players, :sync_date, :datetime

    add_column :clubs, :source_url, :string
    add_column :clubs, :sync_date, :datetime

    add_column :locations, :source_url, :string
    add_column :locations, :sync_date, :datetime

    add_column :regions, :source_url, :string
    add_column :regions, :sync_date, :datetime

    add_column :league_teams, :source_url, :string
    add_column :league_teams, :sync_date, :datetime

    add_column :season_participations, :source_url, :string
    add_column :season_participations, :sync_date, :datetime
  end
end
