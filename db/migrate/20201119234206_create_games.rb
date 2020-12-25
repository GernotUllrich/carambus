class CreateGames < ActiveRecord::Migration[6.0]
  def change
    create_table :games do |t|
      t.integer :template_game_id
      t.integer :tournament_id
      t.text :roles
      t.text :data
      t.integer :seqno
      t.string :gname
      t.integer :group_no
      t.integer :table_no
      t.integer :round_no
      t.datetime :started_at
      t.datetime :ended_at

      t.timestamps
    end
  end
end
