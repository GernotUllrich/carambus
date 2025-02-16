class CreateGamePlans < ActiveRecord::Migration[7.0]
  def change
    create_table :game_plans do |t|
      t.string :footprint
      t.text :data
      t.string :name

      t.timestamps
    end
  end
end
