class CreateTournamentMonitors < ActiveRecord::Migration
  def change
    create_table :tournament_executions do |t|
      t.integer :tournament_id
      t.text :data
      t.string :state

      t.timestamps null: false
    end
  end
end
