class CreatePlayerClasses < ActiveRecord::Migration
  def change
    create_table :player_classes do |t|
      t.integer :discipline_id
      t.string :shortname

      t.timestamps null: false
    end
  end
end
