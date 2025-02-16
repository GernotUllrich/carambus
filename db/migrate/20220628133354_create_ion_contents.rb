class CreateIonContents < ActiveRecord::Migration[6.1]
  def change
    create_table :ion_contents do |t|
      t.integer :page_id
      t.string :title
      t.text :html
      t.string :level
      t.datetime :scraped_at
      t.datetime :deep_scraped_at
      t.integer :ion_content_id
      t.text :data
      t.integer :position

      t.timestamps
    end
  end
end
