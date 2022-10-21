# frozen_string_literal: true

module FiltersHelper
  def apply_filters(query, columns, search_query)
    searches = @sSearch.to_s.split(/[,&\s]+/)
    searches.each do |search|
      if search =~ /:/
        key, value = search.split(':')
        if value.present?
          columns.each do |ext_name, int_name|
            if int_name.present?
              # TODO: FILTERS
              if int_name =~ / as /
                term, tempname = int_name.split(' as ').map(&:strip)
                # no search on virtual columns
                # query = query.where("(#{tempname} ilike :search)", search: "%#{value}%")
              elsif ext_name =~ /^#{key.strip}/i
                query = if int_name =~ /id$/ || %w[players points sets ba_id ba2_id cc_id balls innings hs sp_g
sp_v g v].include?(int_name.split("\.").last)
                          query.where("(#{int_name} = :isearch)", isearch: value.to_i)
                        else
                          query.where("(#{int_name} ilike :search)", search: "%#{value}%")
                        end
              end
            end
          end
        end
      else
        query = query.where(search_query.to_s, search: "%#{search}%", isearch: search.to_i)
      end
    rescue Exception => e
      e
    end
    query
  end
end
