# PaperTrail configuration for region tagging
PaperTrail.config.track_associations = false

# Configure PaperTrail to automatically set region_id and global_context
# This callback fires for ALL version creation, including:
# - create events (new records)
# - update events (record changes) 
# - destroy events (record deletions)
PaperTrail.config.before_create = lambda do |version|
  # Get the item that this version is tracking
  item = version.item
  
  # Set region_id and global_context if the item includes RegionTaggable
  if item&.respond_to?(:find_associated_region_id)
    region_id = item.find_associated_region_id
    global_context = item.global_context? if item.respond_to?(:global_context?)
    
    version.region_id = region_id
    version.global_context = global_context
    
    # Log for debugging (only in development)
    if Rails.env.development?
      Rails.logger.debug "PaperTrail: Set region_id=#{region_id}, global_context=#{global_context} for #{version.item_type}##{version.item_id} (#{version.event})"
    end
  elsif version.event == "destroy" && version.object.present?
    # For destroy events, the item might not be available because it's been deleted
    # But we can assume it was properly tagged before deletion, so use stored values
    begin
      object_data = YAML.load(version.object)
      if object_data.is_a?(Hash)
        version.region_id = object_data["region_id"]
        version.global_context = object_data["global_context"]
        
        # Log for debugging (only in development)
        if Rails.env.development?
          Rails.logger.debug "PaperTrail: Set region_id=#{version.region_id}, global_context=#{version.global_context} for destroyed #{version.item_type}##{version.item_id}"
        end
      end
    rescue StandardError => e
      Rails.logger.warn "PaperTrail: Could not extract region data from destroyed object: #{e.message}"
    end
  end
end

# Configure PaperTrail to update region_id and global_context on version updates
PaperTrail.config.before_update = lambda do |version|
  # Get the item that this version is tracking
  item = version.item
  
  # Update region_id and global_context if the item includes RegionTaggable
  if item&.respond_to?(:find_associated_region_id)
    region_id = item.find_associated_region_id
    global_context = item.global_context? if item.respond_to?(:global_context?)
    
    version.region_id = region_id
    version.global_context = global_context
    
    # Log for debugging (only in development)
    if Rails.env.development?
      Rails.logger.debug "PaperTrail: Updated region_id=#{region_id}, global_context=#{global_context} for #{version.item_type}##{version.item_id} (#{version.event})"
    end
  end
end 