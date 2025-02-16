class CreateLeagueTeams < ActiveRecord::Migration[6.0]
  def change
    create_table :league_teams do |t|
      t.string :name
      t.string :shortname
      t.integer :league_id
      t.integer :ba_id
      t.integer :club_id

      t.timestamps
    end
  end
end
