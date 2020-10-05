class RegionsDatatable
  include FiltersHelper
  delegate :params, :h, :link_to, :mail_to, :image_tag, :mail_to, :number_to_currency, to: :@view

  def initialize(view, regions)
    @view = view
    @regions = regions
  end

  def as_json(options = {})
    {
        sEcho: params[:sEcho].to_i,
        iTotalRecords: Region.count,
        iTotalDisplayRecords: regions.total_count,
        aaData: data
    }
  end

  private

  def data
    regions.map do |region|
      [
          (image_tag(region.logo) if region.logo.present?),
          link_to(region.shortname, "https://#{region.shortname.downcase}.billardarea.de"),
          link_to(region.name, @view.region_path(region)),
          mail_to(region.email),
          region.address.gsub("\n", "<br />").html_safe,
          link_to(region.country.andand.code, @view.country_path(region.country)),
          "#{(link_to image_tag("ansehen.gif", :width => 26, :height => 22, :border => 0), region) + " " +
              (link_to image_tag("bearbeiten.gif", :width => 26, :height => 22, :border => 0), @view.edit_region_path(region)) + " " +
              (link_to image_tag("loeschen.gif", :width => 26, :height => 22, :border => 0), region, method: :delete, data: {confirm: 'Are you sure?'})}"
      ]
    end
  end

  def regions
    @regions ||= fetch_regions
  end

  def fetch_regions
    regions = Region.order(order).includes(:country)
    if params[:sSearch].present?
      regions = apply_filters(regions, Region::COLUMN_NAMES, "(regions.name ilike :search) or (regions.shortname ilike :search) or (regions.email ilike :search)")
    end
    regions = regions.page(page).per(per_page)
    regions
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
    columns = Region::COLUMN_NAMES.values
    columns[params[:"iSortCol_#{i}"].to_i] if params[:"iSortCol_#{i}"].present?
  end

  def sort_direction(i)
    params[:"sSortDir_#{i}"] == "desc" ? "desc" : "asc"
  end
end