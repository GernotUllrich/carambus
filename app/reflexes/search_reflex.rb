# frozen_string_literal: true

# Generalized search reflex for handling search fields with immediate
# response on any change of the inputs
class SearchReflex < ApplicationReflex
  include Rails.application.routes.url_helpers

  before_reflex do
    # session[:"s_#{params[:controller]}"] = params[:sSearch] if params.has_key?(:sSearch)
    # @sSearch = session[:"s_#{params[:controller]}"] if params[:action] == "index"
  end

  include Pagy::Backend
  DEBUG = true

  def perform
    Rails.application.routes.default_url_options[:host] = request.base_url
    model_name = params[:controller].camelize.singularize
    @model = model_name.constantize

    # Store search parameters
    session["#{model_name.underscore}_search"] ||= {}

    # Update search parameters
    if params[:sSearch].present?
      session["#{model_name.underscore}_search"][:sSearch] = params[:sSearch]
    end

    # Handle sorting parameters
    if params[:sort].present?
      session["#{model_name.underscore}_search"][:sort] = params[:sort]
      session["#{model_name.underscore}_search"][:direction] = params[:direction] || 'asc'
    end

    # Get search parameters from session
    search_params = session["#{model_name.underscore}_search"].symbolize_keys

    # Perform search
    results = SearchService.call(@model.search_hash(search_params))

    # Paginate results
    pagy, records = pagy(results)
    records.load

    Rails.logger.info "Rendering table with #{records.size} records"

    # Send instance variables to view
    instance_variable_set("@#{model_name.underscore.pluralize}", records)
    instance_variable_set("@pagy", pagy)
    instance_variable_set("@search_params", search_params)

    # Render partial
    render partial: "#{model_name.underscore.pluralize}_table", locals: {pagy: @pagy, model_class: @model, records: records}
  end
end
