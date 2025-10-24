# frozen_string_literal: true

# Searchable Concern
# Provides standardized search and filter functionality for models
#
# Usage:
#   class MyModel < ApplicationRecord
#     include Searchable
#
#     COLUMN_NAMES = {
#       "id" => "my_models.id",
#       "Name" => "my_models.name",
#       ...
#     }.freeze
#
#     def self.text_search_sql
#       "(my_models.name ilike :search)"
#     end
#
#     def self.search_joins
#       [:related_model]
#     end
#
#     def self.search_distinct?
#       true
#     end
#   end
module Searchable
  extend ActiveSupport::Concern

  class_methods do
    # Ensure model has COLUMN_NAMES defined (checked at runtime, not at load time)
    def validate_column_names!
      unless const_defined?(:COLUMN_NAMES)
        raise "#{name} must define COLUMN_NAMES constant to use Searchable concern"
      end
    end
    # Standard search_hash implementation
    # Override in model if custom behavior is needed
    def search_hash(params)
      {
        model: self,
        sort: params[:sort],
        direction: sort_direction(params[:direction]),
        search: params[:sSearch],
        column_names: filter_columns,
        raw_sql: text_search_sql,
        joins: search_joins,
        distinct: search_distinct?
      }
    end

    # Returns the filter columns configuration
    # Override in model if custom logic is needed
    def filter_columns
      validate_column_names!
      self::COLUMN_NAMES
    end

    # Returns SQL for text search (when no field specifiers are used)
    # MUST be overridden in model
    def text_search_sql
      raise NotImplementedError, "#{name} must implement text_search_sql class method"
    end

    # Returns the joins needed for searching/filtering
    # Can be array of symbols, strings, or mixed
    # Override in model
    def search_joins
      []
    end

    # Returns whether DISTINCT is needed (to avoid duplicates from joins)
    # Override in model
    def search_distinct?
      false
    end

    # Returns configuration for cascading filters
    # Format: { 'parent_field_id' => ['child_field_id', 'another_child_id'] }
    # Override in model if cascading is needed
    def cascading_filters
      {}
    end

    # Returns field type configuration for UI rendering
    # Override in model if custom field types are needed
    def filter_field_types
      @filter_field_types ||= detect_field_types
    end

    # Auto-detect field types from column names
    def detect_field_types
      types = {}
      
      filter_columns.each do |display_name, column_def|
        types[display_name] = detect_field_type(display_name, column_def)
      end
      
      types
    end

    # Detect field type for a single field
    def detect_field_type(display_name, column_def)
      # Hidden ID fields
      return :hidden if display_name.match?(/^[a-z_]+_id$/) || display_name == 'id'
      
      # External IDs (numeric)
      return :number if display_name.match?(/_(ID|id)$/) && !display_name.match?(/^[a-z_]+_id$/)
      
      # Date fields
      return :date if column_def.include?('::date')
      
      # Reference fields (foreign key lookups)
      return :select if is_reference_field?(display_name, column_def)
      
      # Status fields with predefined values
      return :chips if display_name == 'Status'
      
      # Default to text
      :text
    end

    # Check if field is a reference to another model
    def is_reference_field?(display_name, column_def)
      # Check if the column definition references another table
      return false if column_def.blank?
      
      # Reference fields are those that reference ANOTHER table's identifying column
      # Examples: regions.shortname, clubs.shortname, seasons.name
      reference_pattern = /^(regions|seasons|clubs|disciplines|leagues|parties|tournaments|locations)\.(shortname|name)$/
      
      column_def.match?(reference_pattern)
    end

    # Get display examples for a field (for help tooltips)
    # Override in model for custom examples
    def field_examples(field_name)
      case filter_field_types[field_name]
      when :number
        { description: "Numerischer Wert", examples: ["12345", "> 1000", "<= 500"] }
      when :date
        { description: "Datum", examples: ["2024-01-15", "> 2024-01-01", "heute"] }
      when :select
        { description: "Auswahl aus Liste", examples: [] }
      when :chips
        { description: "Status auswählen", examples: [] }
      when :text
        { description: "Textsuche (Teiltreffer möglich)", examples: ["Meyer", "Berlin", "Ball"] }
      else
        { description: "Filter", examples: [] }
      end
    end

    # Get human-readable field description
    # Override in model for custom descriptions
    def field_description(field_name)
      field_examples(field_name)[:description]
    end
  end
end

