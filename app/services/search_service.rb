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
    results = apply_scope(results)

    if @sSearch.present?
      results_no_query = results
      results = apply_filters(results, @column_names, @raw_sql)
    end
    results
  end

  private

  # Globaler Ausschnitt (Scope-Band): FK-Filter (region_id/season_id/...) aus Current.scope,
  # nur wo das Modell die Spalte fuehrt. Unabhaengig von der User-Suche (@sSearch).
  #
  # Region-Sonderregel (analog Version#for_region): global_context-Records (einer Region
  # zugeordnet, aber regionsuebergreifend gueltig — z.B. DBU-Ligen mit Mannschaften aus
  # mehreren Regionen) werden vom Region-Filter NIE ausgeschlossen.
  def apply_scope(results)
    scope = Current.scope
    return results if scope.blank?

    cols = @model.column_names
    table = @model.table_name
    scope.each do |column, value|
      next if value.blank?
      next unless cols.include?(column.to_s)

      results = if column.to_s == "region_id" && cols.include?("global_context")
                  results.where("#{table}.region_id = :r OR #{table}.global_context = TRUE", r: value)
                else
                  results.where(column => value)
                end
    end
    results
  end
end
