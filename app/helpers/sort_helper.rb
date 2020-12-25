module SortHelper
  def sortable(relation, column, title, options = {})
    matching_column = column.to_s == sort_column(relation.klass)
    direction = sort_direction == "asc" ? "desc" : "asc"

    link_to request.params.merge(sort: column, direction: direction).reject{|k,v| k.to_s == "table_only"}, options do
      concat title
      if matching_column
        caret = sort_direction == "asc" ? "up" : "down"
        concat " "
        concat content_tag(:i, nil, class: "fas fa-caret-#{caret}")
      end
    end
  end
end
