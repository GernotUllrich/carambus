class CreateGamePlanRowCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :game_plan_row_ccs do |t|
      t.integer :cc_id
      t.integer :game_plan_id
      t.integer :discipline_id
      t.integer :home_brett
      t.integer :visitor_brett
      t.integer :sets
      t.integer :score
      t.integer :ppg
      t.integer :ppu
      t.integer :ppv
      t.integer :mpg
      t.integer :pmv

      t.timestamps
    end
  end
end
