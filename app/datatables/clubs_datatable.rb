class ClubsDatatable
  include FiltersHelper
  delegate :params, :h, :link_to, :image_tag, :mail_to, :number_to_currency, to: :@view

  def initialize(view, clubs)
    @view = view
    @clubs = clubs
  end

  def as_json(options = {})
    {
        sEcho: params[:sEcho].to_i,
        iTotalRecords: Club.count,
        iTotalDisplayRecords: clubs.total_count,
        aaData: data
    }
  end

  private

  def data
    clubs.map do |club|
      [
          (club.logo.present? ? ("<img src=\"<%= club.logo %>\"") : ""),
          (link_to club.ba_id, "https://nbv.billardarea.de/cms_clubs/details/#{club.ba_id}"),
          (link_to club.region.name, @view.region_path(club.region) if club.region.present?),
          club.name,
          club.shortname,
          club.homepage == "http://" ? "" : (link_to club.homepage, club.homepage),
          club.status,
          club.founded,
          club.dbu_entry,
          "#{(link_to image_tag("ansehen.gif", :width => 26, :height => 22, :border => 0), club) + " " +
              (link_to image_tag("bearbeiten.gif", :width => 26, :height => 22, :border => 0), @view.edit_club_path(club)) + " " +
              (link_to image_tag("loeschen.gif", :width => 26, :height => 22, :border => 0), club, method: :delete, data: {confirm: 'Are you sure?'})}"
      ]
    end
  end

  def clubs
    @clubs ||= fetch_clubs
  end

  def fetch_clubs
    clubs = Club.order(order).joins(:region)
    if params[:sSearch].present?
      clubs = apply_filters(clubs, Club::COLUMN_NAMES, "(regions.name ilike :search) or (clubs.name ilike :search) or (clubs.shortname ilike :search) or (clubs.email ilike :search)")
    end
    clubs = clubs.page(page).per(per_page)
    clubs
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
    columns = Club::COLUMN_NAMES.values
    columns[params[:"iSortCol_#{i}"].to_i] if params[:"iSortCol_#{i}"].present?
  end

  def sort_direction(i)
    params[:"sSortDir_#{i}"] == "desc" ? "desc" : "asc"
  end
end