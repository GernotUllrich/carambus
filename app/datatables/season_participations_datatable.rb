class SeasonParticipationsDatatable
  delegate :params, :h, :link_to, :image_tag, :mail_to, :number_to_currency, to: :@view

  def initialize(view, season_participations)
    @view = view
    @season_participations = season_participations
  end

  def as_json(options = {})
    {
        sEcho: params[:sEcho].to_i,
        iTotalRecords: SeasonParticipation.count,
        iTotalDisplayRecords: season_participations.total_count,
        aaData: data
    }
  end

  private

  def data
    season_participations.map do |season_participation|
      [
          season_participation.player.lastname,
          season_participation.player.firstname,
          season_participation.player.club.shortname,
          season_participation.season.name,
          "#{(link_to image_tag("ansehen.gif", :width => 26, :height => 22, :border => 0), season_participation) + " " +
              (link_to image_tag("bearbeiten.gif", :width => 26, :height => 22, :border => 0), @view.edit_season_participation_path(season_participation)) + " " +
              (link_to image_tag("loeschen.gif", :width => 26, :height => 22, :border => 0), season_participation, method: :delete, data: {confirm: 'Are you sure?'})}"
      ]
    end
  end

  def season_participations
    @season_participations ||= fetch_season_participations
  end

  def fetch_season_participations
    season_participations = SeasonParticipation.order(order).joins(player: :club).joins(:season)
    if params[:sSearch].present?
      season_participations = season_participations.where("(players.lastname ilike :search) or (players.firstname ilike :search) or (clubs.shortname ilike :search) or (seasons.name ilike :search)", search: "%#{params[:sSearch]}%")
    end
    season_participations = season_participations.page(page).per(per_page)
    season_participations
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
    columns = %w{players.lastname players.firstname clubs.shortname seasons.name}
    columns[params[:"iSortCol_#{i}"].to_i] if params[:"iSortCol_#{i}"].present?
  end

  def sort_direction(i)
    params[:"sSortDir_#{i}"] == "desc" ? "desc" : "asc"
  end
end