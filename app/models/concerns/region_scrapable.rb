# frozen_string_literal: true

# Concern for models that can be tagged with regions during scraping
module RegionScrapable
  extend ActiveSupport::Concern

  class_methods do
    def tag_with_region(records, region)
      return if records.blank? || region.blank?

      # Convert single record to array for consistent handling
      records = Array(records)
      return if records.empty?

      # Collect records by model type for batch tagging
      records_by_type = records.group_by(&:class)

      records_by_type.each do |model_class, model_records|
        # Skip if any record is already tagged with this region
        untagged_records = model_records.reject do |record|
          if record.is_a?(ApplicationRecord)
            record.region_taggings.exists?(region_id: region.id)
          else
            raise "somenthing went wrong"
          end
        end

        next if untagged_records.empty?

        # Create taggings in bulk
        taggings = untagged_records.map do |record|
          {
            taggable_type: model_class.name,
            taggable_id: record.id,
            region_id: region.id,
            created_at: Time.current,
            updated_at: Time.current
          }
        end

        # Insert all taggings in one query
        RegionTagging.insert_all(taggings)
      end
    end
  end
  # Instance method that delegates to class method
  def tag_with_region(region)
    self.class.tag_with_region(self, region)
  end
end
