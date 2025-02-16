class CreateDisciplinePhases < ActiveRecord::Migration[7.0]
  def change
    create_table :discipline_phases do |t|
      t.string :name
      t.integer :discipline_id
      t.integer :parent_discipline_id
      t.integer :position
      t.text :data

      t.timestamps
    end
  end
end
