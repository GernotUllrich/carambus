class CountriesDatatable
  include FiltersHelper
  delegate :params, :h, :link_to, :image_tag, :mail_to, :number_to_currency, to: :@view

  def initialize(view, countries)
    @view = view
    @countries = countries
  end

  def as_json(options = {})
    {
        sEcho: params[:sEcho].to_i,
        iTotalRecords: Country.count,
        iTotalDisplayRecords: countries.total_count,
        aaData: data
    }
  end

  private

  def data
    countries.map do |country|
      [

          country.name,
          country.code,

          "#{(link_to image_tag("ansehen.gif", :width => 26, :height => 22, :border => 0), country) + " " +
              (link_to image_tag("bearbeiten.gif", :width => 26, :height => 22, :border => 0), @view.edit_country_path(country)) + " " +
              (link_to image_tag("loeschen.gif", :width => 26, :height => 22, :border => 0), country, method: :delete, data: {confirm: 'Are you sure?'})}"
      ]
    end
  end

  def countries
    @countries ||= fetch_countries
  end

  def fetch_countries
    countries = Country.order(order)
    if params[:sSearch].present?
      countries = apply_filters(countries, Country::COLUMN_NAMES, "(countries.name ilike :search) or (countries.code ilike :search)")
    end
    countries = countries.page(page).per(per_page)
    countries
  end

  def page
    params[:iDisplayStart].to_i / per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 10
  end

  def order
    ret = (0..12).inject([]) do |memo, i|
      if sort_column(i).present?
        memo << "#{sort_column(i)} #{sort_direction(i)}"
      end
      memo
    end
    ret.join(", ")
  end

  def sort_column(i)
    columns = Country::COLUMN_NAMES.values
    columns[params[:"iSortCol_#{i}"].to_i] if params[:"iSortCol_#{i}"].present?
  end

  def sort_direction(i)
    params[:"sSortDir_#{i}"] == "desc" ? "desc" : "asc"
  end
end