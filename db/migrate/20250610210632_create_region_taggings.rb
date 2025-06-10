class CreateRegionTaggings < ActiveRecord::Migration[7.2]
  def change
    create_table :region_taggings do |t|
      t.references :taggable, polymorphic: true, null: false
      t.references :region, null: false

      t.timestamps
    end

    # Only add indexes if they don't exist
    unless index_exists?(:region_taggings, [:taggable_type, :taggable_id, :region_id], name: 'index_region_taggings_on_taggable_and_region')
      add_index :region_taggings, [:taggable_type, :taggable_id, :region_id], unique: true, name: 'index_region_taggings_on_taggable_and_region'
    end

    unless index_exists?(:region_taggings, :region_id)
      add_index :region_taggings, :region_id
    end

    # Add foreign key without validation
    add_foreign_key :region_taggings, :regions, validate: false
  end
end 