# frozen_string_literal: true

module FiltersHelper
  def apply_filters(query, columns, search_query)
    searches = @sSearch.to_s.split(/[,&\s]+/)
    search_matches = []
    searches.each do |search|
      if /:/.match?(search)
        key, value = search.split(":")
        if value.present?
          comp = nil
          if (m = value.match(/(>=|=|>|<=|<)(.*)/)).present?
            comp = m[1]
            value = m[2].strip
          end
          value = (Date.today - 1.week).to_s if %w[heute today].include?(value)
          columns.each do |ext_name, int_name|
            next if search_matches.include?(key)

            if int_name.present?
              # TODO: FILTERS
              if / as /.match?(int_name)
                int_name.split(" as ").map(&:strip)
                # no search on virtual columns
                # query = query.where("(#{tempname} ilike :search)", search: "%#{value}%")
              elsif /^#{key.strip}/i.match?(ext_name)
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
                search_matches << key
              end
            end
          end
        end
      else
        query = query.where(search_query.to_s, search: "%#{search}%", isearch: (search.to_i == 0 ? -727_272 : search.to_i))
      end
    rescue Exception => e
      e
    end
    query
  end
end
