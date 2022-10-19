class CreateTournamentCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :tournament_ccs do |t|
      t.integer :cc_id
      t.string :context
      t.string :name
      t.string :shortname
      t.string :status
      t.integer :branch_cc_id
      t.string :season
      t.integer :registration_list_cc_id
      t.integer :registration_rule
      t.integer :discipline_id
      t.integer :championship_type_cc_id
      t.integer :category_cc_id
      t.integer :group_cc_id
      t.datetime :tournament_start
      t.integer :tournament_series_cc_id
      t.datetime :tournament_end
      t.time :starting_at
      t.integer :league_climber_quote
      t.decimal :entry_fee, precision: 6, scale: 2
      t.integer :max_players
      t.integer :location_id
      t.string :location_text
      t.text :description
      t.string :poster
      t.string :tender
      t.string :flowchart
      t.string :ranking_list
      t.string :successor_list

      t.timestamps
    end
  end
end
