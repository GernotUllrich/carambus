class CreateTournamentTemplates < ActiveRecord::Migration
  def change
    create_table :tournament_templates do |t|
      t.string :name
      t.integer :discipline_id
      t.integer :points
      t.integer :innings

      t.timestamps null: false
    end
  end
end
