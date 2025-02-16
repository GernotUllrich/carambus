class CreateTournamentPlans < ActiveRecord::Migration[6.0]
  def change
    create_table :tournament_plans do |t|
      t.string :name
      t.text :rulesystem
      t.integer :players
      t.integer :tables
      t.text :more_description
      t.text :even_more_description
      t.string :executor_class
      t.text :executor_params
      t.integer :ngroups
      t.integer :nrepeats

      t.timestamps
    end
  end
end
