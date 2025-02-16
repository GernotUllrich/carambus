class CreateGamePlanCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :game_plan_ccs do |t|
      t.integer :cc_id
      t.string :name
      t.text :data
      t.integer :branch_cc_id
      t.integer :discipline_id
      t.integer :mp_won
      t.integer :mb_draw
      t.integer :mp_lost
      t.integer :znp
      t.integer :vorgabe
      t.boolean :plausi
      t.string :pez_partie
      t.string :bez_brett
      t.integer :rang_partie
      t.integer :rang_mgd
      t.integer :rang_kegel
      t.integer :ersatzspieler_regel
      t.integer :row_type_id

      t.timestamps
    end
  end
end
