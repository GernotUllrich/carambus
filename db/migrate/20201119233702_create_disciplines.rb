class CreateDisciplines < ActiveRecord::Migration[6.0]
  def change
    create_table :disciplines do |t|
      t.string :name
      t.integer :super_discipline_id
      t.integer :table_kind_id
      t.text :data

      t.timestamps
    end
  end
end
