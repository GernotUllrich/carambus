class GameParticipationsDatatable
  include FiltersHelper
  delegate :params, :h, :link_to, :image_tag, :mail_to, :number_to_currency, to: :@view

  def initialize(view, game_participations)
    @view = view
    @game_participations = game_participations
  end

  def as_json(options = {})
    {
        sEcho: params[:sEcho].to_i,
        iTotalRecords: GameParticipation.count,
        iTotalDisplayRecords: game_participations.total_count,
        aaData: data
    }
  end

  private

  def data
    game_participations.map do |game_participation|
      [
          link_to(game_participation.game.seqno, @view.game_path(game_participation.game)),
          link_to(game_participation.game.gname, @view.game_path(game_participation.game)),
          link_to(game_participation.game.tournament.title, @view.tournament_path(game_participation.game.tournament)),
          game_participation.game.tournament.date.to_date,
          link_to("#{game_participation.player.lastname}, #{game_participation.player.firstname}", @view.player_path(game_participation.player)),
          link_to(game_participation.player.club.shortname, @view.club_path(game_participation.player.club)),
          game_participation.role,
          game_participation.points,
          game_participation.result,
          game_participation.innings,
          game_participation.gd,
          game_participation.hs,
          "#{(link_to image_tag("ansehen.gif", :width => 26, :height => 22, :border => 0), game_participation) + " " +
              (link_to image_tag("bearbeiten.gif", :width => 26, :height => 22, :border => 0), @view.edit_game_participation_path(game_participation)) + " " +
              (link_to image_tag("loeschen.gif", :width => 26, :height => 22, :border => 0), game_participation, method: :delete, data: {confirm: 'Are you sure?'})}"
      ]
    end
  end

  def game_participations
    @game_participations ||= fetch_game_participations
  end

  def fetch_game_participations
    game_participations = GameParticipation.joins(:player => {:season_participations => [:club, :season]}).joins(:game => :tournament).where("seasons.id = tournaments.season_id").order(order)
    if params[:sSearch].present?
      game_participations = apply_filters(game_participations, GameParticipation::COLUMN_NAMES, "(players.lastname||', '||players.firstname ilike :search)")
    end
    game_participations = game_participations.page(page).per(per_page)
    game_participations
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
    columns = GameParticipation::COLUMN_NAMES.values
    columns[params[:"iSortCol_#{i}"].to_i] if params[:"iSortCol_#{i}"].present?
  end

  def sort_direction(i)
    params[:"sSortDir_#{i}"] == "desc" ? "desc" : "asc"
  end
end