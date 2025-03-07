require "administrate/base_dashboard"

class PageDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  ATTRIBUTE_TYPES = {
    id: Administrate::Field::Number,
    title: Administrate::Field::String,
    content: Administrate::Field::Text.with_options(searchable: true),
    summary: Administrate::Field::Text,
    super_page: Administrate::Field::BelongsTo.with_options(class_name: "Page"),
    sub_pages: Administrate::Field::HasMany.with_options(class_name: "Page"),
    position: Administrate::Field::Number,
    author: Administrate::Field::Polymorphic,
    content_type: Administrate::Field::Select.with_options(collection: ['markdown']),
    status: Administrate::Field::Select.with_options(collection: ['draft', 'published', 'archived']),
    published_at: Administrate::Field::DateTime,
    tags: Administrate::Field::Jsonb,
    metadata: Administrate::Field::Jsonb,
    crud_minimum_roles: Administrate::Field::Jsonb,
    version: Administrate::Field::String,
    created_at: Administrate::Field::DateTime,
    updated_at: Administrate::Field::DateTime,
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  COLLECTION_ATTRIBUTES = %i[
    title
    status
    super_page
    position
    updated_at
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    title
    summary
    content
    super_page
    sub_pages
    position
    author
    content_type
    status
    published_at
    tags
    crud_minimum_roles
    version
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    title
    summary
    content
    super_page
    position
    content_type
    status
    tags
    crud_minimum_roles
  ].freeze

  # COLLECTION_FILTERS
  # a hash that defines filters that can be used while searching via the search
  # field of the dashboard.
  COLLECTION_FILTERS = {
    status: ->(resources) { resources.where(status: params[:status]) if params[:status].present? },
    super_page_id: ->(resources) { resources.where(super_page_id: params[:super_page_id]) if params[:super_page_id].present? }
  }.freeze

  # Overwrite this method to customize how pages are displayed
  # across all pages of the admin dashboard.
  def display_resource(page)
    page.title
  end
end
