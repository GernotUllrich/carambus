class CreateTableKinds < ActiveRecord::Migration
  TABLE_KINDS = ["Pool", "Snooker", "Small Table", "Match Table", "Large Table"]

  def change
    create_table :table_kinds do |t|
      t.string :name
      t.string :short
      t.text :measures

      t.timestamps null: false
    end
  end
end
