class CreateIonModules < ActiveRecord::Migration[6.1]
  def change
    create_table :ion_modules do |t|
      t.string :module_id
      t.integer :ion_content_id
      t.string :module_type
      t.integer :position
      t.text :html
      t.text :data

      t.timestamps
    end
  end
end
