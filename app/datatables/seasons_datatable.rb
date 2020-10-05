class SeasonsDatatable
  delegate :params, :h, :link_to, :image_tag, :mail_to, :number_to_currency, to: :@view
  #xx PRODUCT_NAMES = ["", "Jahr", "Halbjahr", "Quartal", "Schnupper"]
  def initialize(view, seasons)
    @view = view
    @seasons = seasons
  end

  def as_json(options = {})
    {
        sEcho: params[:sEcho].to_i,
        iTotalRecords: Season.count,
        iTotalDisplayRecords: seasons.total_count,
        aaData: data
    }
  end

  private

  def data
    seasons.map do |season|
      [
          season.ba_id,
          season.name,
          "#{(link_to image_tag("ansehen.gif", :width => 26, :height => 22, :border => 0, :margin => 5), season)+" " +
              (link_to image_tag("bearbeiten.gif", :width => 26, :height => 22, :border => 0, :margin => 5), @view.edit_season_path(season))+" " +
              (link_to image_tag("loeschen.gif", :width => 26, :height => 22, :border => 0, :margin => 5), season, method: :delete, data: { confirm: 'Are you sure?' } )}"
      ]
    end
  end

  def seasons
    @seasons ||= fetch_seasons
  end

  def fetch_seasons
    seasons = Season.order(order)
    if params[:sSearch].present?
      seasons = seasons.where("(name ilike :search) or (ba_id = :search_i )", search_i: params[:sSearch].to_i, search: "%#{params[:sSearch]}%")
    end
    seasons = seasons.page(page).per(per_page)
    seasons
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
    columns = %w[seasons.ba_id seasons.name]
    columns[params[:"iSortCol_#{i}"].to_i] if params[:"iSortCol_#{i}"].present?
  end

  def sort_direction(i)
    params[:"sSortDir_#{i}"] == "desc" ? "desc" : "asc"
  end

end