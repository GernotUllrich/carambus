class CreateAbandonedTournamentCcs < ActiveRecord::Migration[7.0]
  def change
    create_table :abandoned_tournament_ccs do |t|
      t.integer :cc_id, null: false
      t.string :context, null: false
      t.string :region_shortname, null: false
      t.string :season_name, null: false
      t.string :tournament_name, null: false
      t.datetime :abandoned_at, null: false
      t.text :reason
      t.integer :replaced_by_cc_id
      t.integer :replaced_by_tournament_id

      t.timestamps
    end

    add_index :abandoned_tournament_ccs, [:cc_id, :context], unique: true
    add_index :abandoned_tournament_ccs, [:region_shortname, :season_name, :tournament_name], name: 'index_abandoned_tournament_ccs_on_region_season_tournament'
    add_index :abandoned_tournament_ccs, :abandoned_at
  end
end 