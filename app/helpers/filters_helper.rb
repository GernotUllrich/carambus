# frozen_string_literal: true

module FiltersHelper
  def apply_filters(query, columns, search_query)
    searches = parse_search_terms(@sSearch.to_s)
    search_matches = []
    
    # Separate plain text searches from field-specific filters
    plain_searches = searches.select { |s| !/:/.match?(s) }
    field_searches = searches.select { |s| /:/.match?(s) }
    
    # Apply plain text searches with AND logic if raw_sql is available
    if plain_searches.any? && search_query.present?
      plain_searches.each do |search_term|
        query = query.where(search_query, search: "%#{search_term}%", isearch: search_term.to_i)
      end
    end
    
    # Apply field-specific filters
    field_searches.each do |search|
      if /:/.match?(search)
        key, value = search.split(":")
        if value.present?
          comp = nil
          if (m = value.match(/(>=|=|>|<=|<)(.*)/)).present?
            comp = m[1]
            value = m[2].strip
          end
          
          # Parse relative date expressions
          value = parse_relative_date(value) if value.present?
          
          # First try exact match (case-insensitive), then prefix match
          matched_column = nil
          matched_name = nil
          
          columns.each do |ext_name, int_name|
            next if search_matches.include?(key)
            next unless int_name.present?
            
            # Exact match has priority
            if ext_name.downcase == key.strip.downcase
              matched_column = int_name
              matched_name = ext_name
              break
            # Prefix match as fallback
            elsif matched_column.nil? && ext_name.downcase.start_with?(key.strip.downcase)
              matched_column = int_name
              matched_name = ext_name
            end
          end
          
          if matched_column.present?
            int_name = matched_column
            
            if int_name.present?
              # TODO: FILTERS
              if / as /.match?(int_name)
                int_name.split(" as ").map(&:strip)
                # no search on virtual columns
                # query = query.where("(#{tempname} ilike :search)", search: "%#{value}%")
              else
                query = if int_name =~ /id$/ || %w[players points sets ba_id ba2_id cc_id balls innings hs sp_g
                                                 sp_v g v].include?(int_name.split(".").last)
                        query.where("(#{int_name} #{comp.present? ? comp : "="} :isearch)", isearch: (value.to_i != 0 ? value.to_i : -7_235_553))
                      elsif /::date$/.match?(int_name)
                        query.where("(#{int_name} #{comp.present? ? comp : "="} :search)", search: value)
                      elsif /\|\|/.match?(int_name)
                        vals = int_name.split(/\|\|/)
                        arr = []
                        vals.each do |val|
                          arr << "#{val} ilike '#{value}'"
                        end
                        arr.present? ? query.where(arr.join(" or ")) : query
                      else
                        query.where("(#{int_name} #{comp.present? ? comp : "ilike"} :search)",
                                    search: (comp.present? ? value : "%#{value.gsub('%20', ' ')}%").to_s)
                      end
              end
              search_matches << key
            end
          end
        end
      end
    rescue StandardError => e
      Rails.logger.error "Error in apply_filters: #{e.message}\n#{e.backtrace.join("\n")}"
      # Return the original query instead of the exception to prevent hanging
      query
    end
    query
  end
  
  private
  
  # Parse search terms, respecting quoted strings and field:value pairs with spaces
  # Examples:
  #   'Location:"BC Wedel" Season:2025/2026' => ['Location:BC Wedel', 'Season:2025/2026']
  #   'Location:BC Wedel Season:2025/2026' => ['Location:BC', 'Wedel', 'Season:2025/2026'] (backwards compatible)
  #   'Meyer Hamburg' => ['Meyer', 'Hamburg']
  def parse_search_terms(search_string)
    return [] if search_string.blank?
    
    terms = []
    current_term = ""
    in_quotes = false
    quote_char = nil
    
    i = 0
    while i < search_string.length
      char = search_string[i]
      
      # Handle quotes
      if ['"', "'"].include?(char) && !in_quotes
        in_quotes = true
        quote_char = char
        i += 1
        next
      elsif char == quote_char && in_quotes
        in_quotes = false
        quote_char = nil
        # Don't skip the next character, it might be a separator
        i += 1
        # Check if we should finalize the current term
        if i >= search_string.length || [',', '&', ' '].include?(search_string[i])
          terms << current_term unless current_term.blank?
          current_term = ""
        end
        next
      end
      
      # Handle separators (space, comma, ampersand)
      if !in_quotes && [',', '&', ' '].include?(char)
        unless current_term.blank?
          terms << current_term
          current_term = ""
        end
        i += 1
        next
      end
      
      # Regular character
      current_term += char
      i += 1
    end
    
    # Add the last term if exists
    terms << current_term unless current_term.blank?
    
    terms.reject(&:blank?)
  end
  
  # Parse relative date expressions like "heute-14", "today-2w", "heute+1m"
  def parse_relative_date(value)
    return value unless value.is_a?(String)
    
    # Match patterns like: heute, heute-14, heute-2w, heute+1m, today-7, etc.
    if (m = value.match(/^(heute|today)([+-])?(\d+)?([dwm])?$/i))
      base_date = Date.today
      operator = m[2]  # + or -
      amount = m[3]&.to_i || 0
      unit = m[4]&.downcase  # d=days, w=weeks, m=months
      
      if operator && amount > 0
        offset = case unit
                 when 'w' then amount.weeks
                 when 'm' then amount.months
                 else amount.days  # default to days, or 'd'
                 end
        
        result_date = operator == '+' ? base_date + offset : base_date - offset
        return result_date.to_s
      else
        # Just "heute" or "today" without offset
        return base_date.to_s
      end
    end
    
    value  # Return unchanged if no match
  end
end
