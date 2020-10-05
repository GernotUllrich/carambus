class CreateDisciplines < ActiveRecord::Migration
  def change
    create_table :disciplines do |t|
      t.string :name
      t.string :table_size

      t.timestamps null: false
    end
  end
end
