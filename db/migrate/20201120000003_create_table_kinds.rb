class CreateTableKinds < ActiveRecord::Migration[6.0]
  def change
    create_table :table_kinds do |t|
      t.string :name
      t.string :short
      t.text :measures

      t.timestamps
    end
  end
end
