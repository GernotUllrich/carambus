require "administrate/base_dashboard"

class SettingDashboard < Administrate::BaseDashboard
  def self.model
    Setting
  end

  def display_resource(_)
    "Settings"
  end

  ATTRIBUTE_TYPES = {}.freeze
  COLLECTION_ATTRIBUTES = [].freeze
  SHOW_PAGE_ATTRIBUTES = [].freeze
  FORM_ATTRIBUTES = [].freeze
end 