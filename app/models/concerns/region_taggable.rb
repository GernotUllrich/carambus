module RegionTaggable
  extend ActiveSupport::Concern

  included do

    after_save :update_region_taggings
    after_destroy :update_region_taggings
  end

  def update_region_taggings
    return if Carambus.config.carambus_api_url.present?

    if PaperTrail.request.enabled?
      version = versions.last
      if version
        version_region_id = self.region_id
        version.update_column(:region_id, version_region_id)
      end
    end
  rescue StandardError => e
    Rails.logger.info("Error during region tagging: #{e} #{e.backtrace.join("\n")}")
  end

end
