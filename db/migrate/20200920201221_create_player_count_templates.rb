class CreatePlayerCountTemplates < ActiveRecord::Migration
  def change
    create_table :player_count_templates do |t|
      t.string :name
      t.integer :tournament_template_id
      t.integer :players
      t.integer :template_id

      t.timestamps null: false
    end
  end
end
