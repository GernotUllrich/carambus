# frozen_string_literal: true

# config/initializers/location.rb
Rails.application.config.after_initialize do
  unless Rails.env == "test"
    @location = Location.find(Rails.application.credentials[:location_id])
    @location.tables.each(&:table_monitor!)
  end
end
