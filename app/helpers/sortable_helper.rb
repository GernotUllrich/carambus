module SortableHelper
  def sortable(scope, column, title = nil, params = {}, options = {})
    title ||= column.titleize
    css_class = options[:class] || ''
    direction = (column.to_s == params[:sort] && params[:direction] == 'asc') ? 'desc' : 'asc'
    icon = sort_icon(column.to_s, params[:sort], params[:direction])
    
    # Get the current search value from either params or session
    current_controller = params[:controller]
    search_value = params[:sSearch].presence || session[:"s_#{current_controller}"]
    
    # Create a new hash with permitted parameters
    link_params = {
      sort: column,
      direction: direction,
      sSearch: search_value,
      locale: params[:locale]
    }.compact

    # Add any additional permitted parameters you need
    permitted_params = [:page, :per_page, :format].each_with_object({}) do |key, hash|
      hash[key] = params[key] if params[key].present?
    end
    
    link_params.merge!(permitted_params)
    
    # Generate the URL with the current path to ensure we're not using a stale URL
    url = url_for(link_params)
    
    link_to(safe_join([title.html_safe, icon]), 
            url,
            class: css_class)
  end

  private

  def sort_icon(column, sort_column, sort_direction)
    return content_tag(:span, '', class: 'ml-1') unless column == sort_column

    icon_class = sort_direction == 'asc' ? 'fas fa-sort-up' : 'fas fa-sort-down'
    content_tag(:i, '', class: "#{icon_class} ml-1")
  end
end 