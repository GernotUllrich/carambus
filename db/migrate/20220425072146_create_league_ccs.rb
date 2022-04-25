class CreateLeagueCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :league_ccs do |t|
      t.integer :cc_id
      t.string :name
      t.integer :season_cc_id
      t.integer :league_id
      t.string :context

      t.timestamps
    end
  end
end
