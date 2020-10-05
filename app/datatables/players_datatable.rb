class PlayersDatatable
  delegate :params, :h, :link_to, :image_tag, :mail_to, :number_to_currency, to: :@view
  #xx PRODUCT_NAMES = ["", "Jahr", "Halbjahr", "Quartal", "Schnupper"]
  def initialize(view, players)
    @view = view
    @players = players
  end

  def as_json(options = {})
    {
        sEcho: params[:sEcho].to_i,
        iTotalRecords: Player.count,
        iTotalDisplayRecords: players.total_count,
        aaData: data
    }
  end

  private

  def data
    players.map do |player|
      [
          "#{(link_to player.ba_id, @view.player_path(player))}",
          (link_to player.club.shortname, @view.club_path(player.club) if player.andand.club.present?),
          player.lastname,
          player.firstname,
          player.title,
          "#{(link_to image_tag("ansehen.gif", :width => 26, :height => 22, :border => 0, :margin => 5), player)+" " +
              (link_to image_tag("bearbeiten.gif", :width => 26, :height => 22, :border => 0, :margin => 5), @view.edit_player_path(player))+" " +
              (link_to image_tag("loeschen.gif", :width => 26, :height => 22, :border => 0, :margin => 5), player, method: :delete, data: { confirm: 'Are you sure?' } )}"
      ]
    end
  end

  def players
    @players ||= fetch_players
  end

  def fetch_players
      players = Player.order(order).joins(:club)
    if params[:sSearch].present?
      players = players.where("(players.ba_id > 0) and ((lastname ilike :search) or (firstname ilike :search) or ((firstname || ' ' || lastname) ilike :search) or (clubs.shortname ilike :search) or (clubs.name ilike :search) or (players.ba_id = :search_i))", search_i: params[:sSearch].to_i, search: "%#{params[:sSearch]}%")
    end
    players = players.page(page).per(per_page)
    players
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
    columns = %w[ba_id shortname lastname firstname title]
    columns[params[:"iSortCol_#{i}"].to_i] if params[:"iSortCol_#{i}"].present?
  end

  def sort_direction(i)
    params[:"sSortDir_#{i}"] == "desc" ? "desc" : "asc"
  end

end