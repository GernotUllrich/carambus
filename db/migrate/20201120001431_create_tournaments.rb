class CreateTournaments < ActiveRecord::Migration[6.0]
  def change
    create_table :tournaments do |t|
      t.string :title
      t.integer :discipline_id
      t.string :modus
      t.string :age_restriction
      t.datetime :date
      t.datetime :accredation_end
      t.text :location
      t.integer :hosting_club_id
      t.integer :ba_id
      t.integer :season_id
      t.integer :region_id
      t.datetime :end_date
      t.string :plan_or_show
      t.string :single_or_league
      t.string :shortname
      t.text :data
      t.string :ba_state
      t.string :state
      t.datetime :last_ba_sync_date
      t.string :player_class
      t.integer :tournament_plan_id
      t.integer :innings_goal
      t.integer :balls_goal
      t.boolean :handicap_tournier

      t.timestamps
    end
  end
end
