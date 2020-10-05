module FiltersHelper
  def apply_filters(query, columns, search_query)
    searches = params[:sSearch].split(/[,&]/)
    searches.each do |search|
      if search =~ /:/
        key, value = search.split(":")
        if value.present?
          columns.each do |ext_name, int_name|
            if int_name.present?
              #TODO FILTERS
              if ext_name =~ /^#{key.strip}/i
                if int_name =~ /id$/
                  query = query.where("(#{int_name} = :isearch)", isearch: value.to_i)
                else
                  query = query.where("(#{int_name} ilike :search)", search: "%#{value}%")
                end
              end
            end
          end
        end
      else
        query = query.where("#{search_query}", search: "%#{search}%", isearch: search.to_i)
      end
    end
    return query
  end
end
