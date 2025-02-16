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
    results = SearchService.call(params[:controller].camelize.singularize.constantize.search_hash(params))
    @pagy, records = pagy(results, request_path: "/#{params[:controller]}")
    instance_variable_set(:"@#{params[:controller]}", records)
    Rails.logger.debug "Query is #{instance_variable_get(:"@#{params[:controller]}").to_sql}" if DEBUG
    Rails.logger.debug "Before Morph: #{instance_variable_get(:"@#{params[:controller]}").inspect}" if DEBUG
    begin
      morph "#table_wrapper",
            render(partial: "#{params[:controller]}/#{params[:controller]}_table",
                   assigns: { pagy: @pagy, :"#{params[:controller]}" => instance_variable_get(:"@#{params[:controller]}") },
                   locals: {request: request})
    rescue StandardError => e
      Rails.logger.debug "In Morph: #{e}, #{e.backtrace.inspect}"
    end
      Rails.logger.debug "After Morph: #{instance_variable_get(:"@#{params[:controller]}").inspect}" if DEBUG
  end
end
