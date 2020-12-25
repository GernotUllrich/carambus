class CreateVersions < ActiveRecord::Migration[6.0]
  def change
    create_table :versions do |t|
      t.string :item_type
      t.bigint :item_id
      t.string :event
      t.string :whodunnit
      t.text :object
      t.text :object_changes

      t.timestamps
    end
  end
end
