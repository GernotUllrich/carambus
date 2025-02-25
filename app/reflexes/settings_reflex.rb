class SettingsReflex < ApplicationReflex
  include ActionView::Helpers::FormOptionsHelper
  include ActionView::Helpers::FormTagHelper

  def update_selectors
    Rails.logger.info "=== REFLEX WURDE AUSGELÖST ==="
    Rails.logger.info "Element value: #{element.value}"

    region = Region.find_by_shortname(element.value)

    @locations = region ? region.locations.where.not(name: "").order(:name) : []
    @clubs = region ? region.clubs.where.not(name: "").order(:name) : []

    morph "#location-select", render(partial: "admin/settings/location_select", locals: {
      locations: @locations
    })

    morph "#club-select", render(partial: "admin/settings/club_select", locals: {
      clubs: @clubs
    })
  end
end
