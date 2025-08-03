# frozen_string_literal: true

class SearchService < ApplicationService
  include FiltersHelper
  def initialize(options = {})
    super()
    @model = options[:model]
    @sort = options[:sort]
    @direction = options[:direction]
    @sSearch = options[:search].to_s.gsub(/&/, "%26")
    @column_names = options[:column_names]
    @raw_sql = options[:raw_sql]
    @joins = options[:joins]
    @distinct = options[:distinct]
  end

  def call
    results = @model
    results = results.joins(@joins) if @joins
    results = results.sort_by_params(@sort, @direction)
    results = results.distinct if @distinct

    if @sSearch.present?
      results_no_query = results
      results = apply_filters(results, @column_names, @raw_sql)
    end
    results
  end
end
