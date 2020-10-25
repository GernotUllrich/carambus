class GamesDatatable
  include FiltersHelper
  delegate :params, :h, :link_to, :image_tag, :mail_to, :number_to_currency, to: :@view

  def initialize(view, games)
    @view = view
    @games = games
  end

  def as_json(options = {})
    {
        sEcho: params[:sEcho].to_i,
        iTotalRecords: Game.count,
        iTotalDisplayRecords: games.total_count,
        aaData: data
    }
  end

  private

  def data
    games.map do |game|
      [
          link_to(game.tournament.date.to_date, @view.tournament_path(game.tournament)),
          link_to(game.tournament.title, @view.tournament_path(game.tournament)),
          link_to(game.data.inspect, @view.game_participations_path(sSearch: @sSearch)),
          "#{(link_to image_tag("ansehen.gif", :width => 26, :height => 22, :border => 0), game) + " " +
              (link_to image_tag("bearbeiten.gif", :width => 26, :height => 22, :border => 0), @view.edit_game_path(game)) + " " +
              (link_to image_tag("loeschen.gif", :width => 26, :height => 22, :border => 0), game, method: :delete, data: {confirm: 'Are you sure?'})}"
      ]
    end
  end

  def games
    @games ||= fetch_games
  end

  def fetch_games
    @sSearch = params[:sSearch]
    games = Game.includes(:tournament).order(order)
    if params[:sSearch].present?
      games = apply_filters(games, Game::COLUMN_NAMES, "(tournaments.title ilike :search) or (games.data ilike :search)")
    end
    games = games.page(page).per(per_page)
    games
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
    columns = Game::COLUMN_NAMES.values
    columns[params[:"iSortCol_#{i}"].to_i] if params[:"iSortCol_#{i}"].present?
  end

  def sort_direction(i)
    params[:"sSortDir_#{i}"] == "desc" ? "desc" : "asc"
  end
end