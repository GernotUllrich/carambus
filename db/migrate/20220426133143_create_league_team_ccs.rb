class CreateLeagueTeamCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :league_team_ccs do |t|
      t.integer :cc_id
      t.string :name
      t.string :shortname
      t.integer :league_cc_id
      t.integer :league_team_id
      t.text :data

      t.timestamps
    end
  end
end
