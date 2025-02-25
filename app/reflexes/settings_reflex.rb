class SettingsReflex < ApplicationReflex
  include ActionView::Helpers::FormOptionsHelper
  include ActionView::Helpers::FormTagHelper

  def update_selectors
    Rails.logger.info "=== REFLEX WURDE AUSGELÖST ==="
    Rails.logger.info "Element value: #{element.value}"

    region = Region.find_by_shortname(element.value)

    @locations = region ? region.locations.order(:name) : [] # .map { |l| [l.name, l.id.to_s] } : []
    @clubs = region ? region.clubs.where.not(name: "").order(:name) : [] # .map { |c| [c.name, c.id.to_s] } : []

    morph "#location-select", render(partial: "admin/settings/location_select", locals: {
      locations: @locations,
      config: Carambus.config
    })

    morph "#club-select", render(partial: "admin/settings/club_select", locals: {
      clubs: @clubs,
      config: Carambus.config
    })
  end
end
