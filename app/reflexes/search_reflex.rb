# frozen_string_literal: true

# Generalized search reflex for handling search fields with immediate
# response on any change of the inputs
class SearchReflex < ApplicationReflex

  before_reflex do
    # session[:"s_#{params[:controller]}"] = params[:sSearch] if params.has_key?(:sSearch)
    # @sSearch = session[:"s_#{params[:controller]}"] if params[:action] == "index"
  end

  include Pagy::Backend
  DEBUG = true

  def perform
    Rails.logger.debug "SearchReflex is triggered" if DEBUG
    params[:sSearch] = element[:value]
    
    # Get the model class from the controller name
    model_class = params[:controller].camelize.singularize.constantize
    
    # Get search hash from the model
    search_hash = model_class.search_hash(params)
    
    # Call the search service
    results = SearchService.call(search_hash)
    
    @pagy, records = pagy(results, request_path: "/#{params[:controller]}")
    instance_variable_set(:"@#{params[:controller]}", records)
    
    Rails.logger.debug "Search term: #{params[:sSearch].inspect}" if DEBUG
    Rails.logger.debug "Records empty?: #{records.empty?}" if DEBUG
    Rails.logger.debug "Records count: #{records.count}" if DEBUG
    
    begin
      if records.empty? && params[:sSearch].present?
        Rails.logger.debug "Showing no results warning" if DEBUG
        warning_html = <<~HTML
          <div class="rounded shadow">
            <div class="my-4 text-sm text-amber-600 dark:text-amber-400 bg-amber-50 dark:bg-amber-900/20 rounded-md p-4 text-center">
              #{I18n.t('shared.search.no_results', query: params[:sSearch], default: "No results found for '#{params[:sSearch]}'")}
            </div>
          </div>
        HTML
        
        morph "#table_wrapper", warning_html
      else
        Rails.logger.debug "Rendering table with #{records.count} records" if DEBUG
        morph "#table_wrapper",
              render(partial: "#{params[:controller]}/#{params[:controller]}_table",
                     assigns: { 
                       pagy: @pagy, 
                       :"#{params[:controller]}" => instance_variable_get(:"@#{params[:controller]}"),
                       model_class: model_class
                     },
                     locals: {request: request})
      end
    rescue StandardError => e
      Rails.logger.error "Error in SearchReflex: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end
