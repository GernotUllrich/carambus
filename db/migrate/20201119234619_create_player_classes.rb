class CreatePlayerClasses < ActiveRecord::Migration[6.0]
  def change
    create_table :player_classes do |t|
      t.integer :discipline_id
      t.string :shortname

      t.timestamps
    end
  end
end
