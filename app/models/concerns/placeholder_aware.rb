# frozen_string_literal: true

# Concern for models that can have placeholder references
# Provides methods to detect and manage placeholder/unknown records
module PlaceholderAware
  extend ActiveSupport::Concern

  included do
    # Scope to find records with placeholder references
    scope :with_placeholders, -> {
      where_clause = placeholder_conditions.join(' OR ')
      where(where_clause) if where_clause.present?
    }
    
    # Scope to find records without placeholder references
    scope :complete, -> {
      where_clause = placeholder_conditions.map { |c| "NOT (#{c})" }.join(' AND ')
      where(where_clause) if where_clause.present?
    }
  end

  class_methods do
    # Define which fields can have placeholder values
    # Override in including class if needed
    def placeholder_fields
      {}
    end
    
    # Generate SQL conditions to find placeholder references
    def placeholder_conditions
      conditions = []
      
      placeholder_fields.each do |field, placeholder_id|
        if placeholder_id.is_a?(Proc)
          # Dynamic lookup
          id = placeholder_id.call
          # Include both placeholder ID and NULL values
          conditions << "(#{table_name}.#{field} = #{id} OR #{table_name}.#{field} IS NULL)" if id.present?
        elsif placeholder_id.present?
          # Static ID - include both placeholder ID and NULL values
          conditions << "(#{table_name}.#{field} = #{placeholder_id} OR #{table_name}.#{field} IS NULL)"
        else
          # Lookup by name pattern - include NULL values
          conditions << "(#{table_name}.#{field} IN (SELECT id FROM #{field}s WHERE name LIKE '%Unknown%') OR #{table_name}.#{field} IS NULL)"
        end
      end
      
      conditions
    end
    
    # Get placeholder ID for a field
    def placeholder_id_for(field)
      placeholder_fields[field]
    end
  end

  # Instance methods
  
  # Check if this record has any placeholder references
  def has_placeholders?
    self.class.placeholder_fields.any? do |field, _|
      is_placeholder_field?(field)
    end
  end
  
  # Check if a specific field is a placeholder
  def is_placeholder_field?(field)
    return false unless respond_to?(field)
    
    value = send(field)
    
    # If value is nil, check if we have a placeholder ID defined for this field
    # If yes, nil is also considered a placeholder (incomplete)
    if value.nil?
      return self.class.placeholder_fields.key?(field)
    end
    
    # Check if it's the placeholder ID
    placeholder_info = self.class.placeholder_id_for(field)
    if placeholder_info.is_a?(Proc)
      placeholder_id = placeholder_info.call
      return value == placeholder_id if placeholder_id.present?
    elsif placeholder_info.is_a?(Integer)
      return value == placeholder_info
    end
    
    # Check if it's a placeholder record by name
    begin
      associated_record = send(field.to_s.gsub('_id', ''))
      return false unless associated_record.respond_to?(:name)
      
      associated_record.name&.include?('Unknown')
    rescue
      false
    end
  end
  
  # Get list of placeholder fields for this record
  def placeholder_field_names
    self.class.placeholder_fields.keys.select { |field| is_placeholder_field?(field) }
  end
  
  # Get human-readable description of placeholder fields
  def placeholder_description
    fields = placeholder_field_names
    return nil if fields.empty?
    
    fields.map do |field|
      association_name = field.to_s.gsub('_id', '').titleize
      "#{association_name} is unknown"
    end.join(', ')
  end
  
  # Check if this record itself is a placeholder
  def is_placeholder?
    return false unless respond_to?(:name)
    name&.include?('Unknown') || 
      (respond_to?(:data) && parsed_data.dig('placeholder') == true)
  end
  
  private
  
  def parsed_data
    return {} unless respond_to?(:data)
    return {} if data.blank?
    
    if data.is_a?(String)
      JSON.parse(data) rescue {}
    else
      data
    end
  end
end
