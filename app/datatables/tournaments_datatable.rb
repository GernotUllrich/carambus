class TournamentsDatatable
  include FiltersHelper
  delegate :params, :h, :link_to, :image_tag, :mail_to, :number_to_currency, to: :@view

  def initialize(view, tournaments)
    @view = view
    @tournaments = tournaments
  end

  def as_json(options = {})
    {
        sEcho: params[:sEcho].to_i,
        iTotalRecords: Tournament.count,
        iTotalDisplayRecords: tournaments.total_count,
        aaData: data
    }
  end

  private

  def data
    tournaments.includes(:region, :season, :discipline).map do |tournament|
      [
          link_to(tournament.ba_id, "https://#{tournament.region.shortname.downcase}.billardarea.de/cms_#{tournament.single_or_league}/#{tournament.plan_or_show}/#{tournament.ba_id}"),
          tournament.ba_state,
          link_to(tournament.title, @view.tournament_path(tournament)),
          tournament.shortname,
          (link_to(tournament.discipline.name, @view.discipline_path(tournament.discipline)) if tournament.discipline.present?),
          link_to(tournament.region.name, @view.region_path(tournament.region)),
          link_to(tournament.season.name, @view.season_path(tournament.season)),
          tournament.plan_or_show,
          tournament.single_or_league,
          "#{(link_to image_tag("ansehen.gif", :width => 26, :height => 22, :border => 0), tournament) + " " +
              (link_to image_tag("bearbeiten.gif", :width => 26, :height => 22, :border => 0), @view.edit_tournament_path(tournament)) + " " +
              (link_to image_tag("loeschen.gif", :width => 26, :height => 22, :border => 0), tournament, method: :delete, data: {confirm: 'Are you sure?'})}"
      ]
    end
  end

  def tournaments
    @tournaments ||= fetch_tournaments
  end

  def fetch_tournaments
    tournaments = Tournament.order(order).joins(:region, :season, :discipline)
    if params[:sSearch].present?
      tournaments = apply_filters(tournaments, Tournament::COLUMN_NAMES, "(tournaments.ba_id = :isearch) or (tournaments.title ilike :search) or (tournaments.shortname ilike :search) or (regions.name ilike :search) or (seasons.name ilike :search) or (tournaments.plan_or_show ilike :search) or (tournaments.single_or_league ilike :search)")
    end
    tournaments = tournaments.page(page).per(per_page)
    tournaments
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
    columns = Tournament::COLUMN_NAMES.values
    columns[params[:"iSortCol_#{i}"].to_i] if params[:"iSortCol_#{i}"].present?
  end

  def sort_direction(i)
    params[:"sSortDir_#{i}"] == "desc" ? "desc" : "asc"
  end
end