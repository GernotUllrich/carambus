class CreateSeasonCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :season_ccs do |t|
      t.integer :cc_id
      t.string :name
      t.integer :season_id
      t.integer :competition_cc_id
      t.string :context

      t.timestamps
    end
  end
end
