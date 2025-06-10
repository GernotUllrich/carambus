class ValidateRegionTaggingsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :region_taggings, :regions
  end
end
