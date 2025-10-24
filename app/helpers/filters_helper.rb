# frozen_string_literal: true

module FiltersHelper
  def apply_filters(query, columns, search_query)
    searches = @sSearch.to_s.split(/[,&\s]+/).reject(&:blank?)
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
          value = (Date.today - 1.week).to_s if %w[heute today].include?(value)
          
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
end
