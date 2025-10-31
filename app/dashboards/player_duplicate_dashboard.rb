require "administrate/base_dashboard"

# Minimal dashboard for PlayerDuplicates
# This is not actually used by Administrate (we use custom controller/views)
# but Administrate requires it to exist
class PlayerDuplicateDashboard < Administrate::BaseDashboard
  def self.model
    Player
  end

  def display_resource(_)
    "Player Duplicates"
  end

  ATTRIBUTE_TYPES = {}.freeze
  COLLECTION_ATTRIBUTES = [].freeze
  SHOW_PAGE_ATTRIBUTES = [].freeze
  FORM_ATTRIBUTES = [].freeze
end

