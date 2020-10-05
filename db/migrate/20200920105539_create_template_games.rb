class CreateTemplateGames < ActiveRecord::Migration
  def change
    create_table :template_games do |t|
      t.string :name
      t.integer :template_id
      t.text :remarks

      t.timestamps null: false
    end
  end
end
