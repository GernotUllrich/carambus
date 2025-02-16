class CreateTournamentMonitors < ActiveRecord::Migration[6.0]
  def change
    create_table :tournament_monitors do |t|
      t.integer :tournament_id
      t.text :data
      t.string :state
      t.integer :innings_goal
      t.integer :balls_goal

      t.timestamps
    end
  end
end
