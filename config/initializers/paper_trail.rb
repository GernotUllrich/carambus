# PaperTrail configuration for region tagging

# Note: In this version of PaperTrail, we cannot use before_create/before_update callbacks
# Instead, we rely on the RegionTaggable concern to handle region_id and global_context
# The Version model will be updated through the normal save process

# Configure PaperTrail to use YAML serializer (default)
PaperTrail.config.serializer = PaperTrail::Serializers::YAML 