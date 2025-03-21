require "administrate/base_dashboard"

class RegionDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name: Field::String,
    shortname: Field::String,
    logo: Field::String,
    email: Field::String,
    address: Field::String,
    telefon: Field::String,
    fax: Field::String,
    website: Field::String,
    opening: Field::String,
    dbu_name: Field::String,
    clubs: Field::HasMany,
    leagues: Field::HasMany,
    tournaments: Field::HasMany,
    country: Field::BelongsTo,
    source_url: Field::String,
    cc_id: Field::Number,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  COLLECTION_ATTRIBUTES = %i[
    name
    shortname
    clubs
    leagues
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    name
    shortname
    logo
    email
    address
    telefon
    fax
    website
    opening
    dbu_name
    country
    clubs
    leagues
    tournaments
    source_url
    cc_id
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    name
    shortname
    logo
    email
    address
    telefon
    fax
    website
    opening
    dbu_name
    country
    source_url
    cc_id
  ].freeze

  # COLLECTION_FILTERS
  # a hash that defines filters that can be used while searching via the search
  # field of the dashboard.
  COLLECTION_FILTERS = {}.freeze

  # Custom links for the show page
  def show_page_links
    [
      {
        text: "Rankings",
        url: :rankings_admin_region_path,
        icon: "trophy"
      }
    ]
  end

  # Overwrite this method to customize how regions are displayed
  # across all pages of the admin dashboard.
  def display_resource(region)
    region.name
  end
end 