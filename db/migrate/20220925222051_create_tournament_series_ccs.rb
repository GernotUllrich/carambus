class CreateTournamentSeriesCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :tournament_series_ccs do |t|
      t.integer :cc_id
      t.string :name
      t.integer :branch_cc_id
      t.string :season
      t.integer :valuation
      t.integer :series_valuation
      t.integer :no_tournaments
      t.string :point_formula
      t.integer :min_points
      t.integer :point_fraction
      t.decimal :price_money, precision: 9, scale: 2
      t.string :currency
      t.string :club_id
      t.integer :show_jackpot
      t.decimal :jackpot, precision: 9, scale: 2
      t.string :status
      t.text :data

      t.timestamps
    end
  end
end
