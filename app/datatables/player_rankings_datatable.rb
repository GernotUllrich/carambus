class PlayerRankingsDatatable
  include FiltersHelper
  delegate :params, :h, :link_to, :image_tag, :mail_to, :number_to_currency, to: :@view

  def initialize(view, player_rankings)
    @view = view
    @player_rankings = player_rankings
    @player_rankings
  end

  def as_json(options = {})
    {
        sEcho: params[:sEcho].to_i,
        iTotalRecords: PlayerRanking.count,
        iTotalDisplayRecords: player_rankings.total_count,
        aaData: data
    }
  end

  private

  def data
    player_rankings.includes(:player, :discipline, :region, :season).map do |player_ranking|
      club = player_ranking.season.season_participations.where("season_participations.player_id = ?", player_ranking.player.id).first.club
      [
          player_ranking.rank,
          link_to("#{player_ranking.player.lastname}, #{player_ranking.player.firstname}", @view.player_path(player_ranking.player)),
          link_to("#{player_ranking.region.shortname}", @view.region_path(player_ranking.region)),
          link_to("#{club.shortname}", @view.club_path(club)),
          link_to("#{player_ranking.season.name}", @view.season_path(player_ranking.season)),
          player_ranking.discipline.name,
          player_ranking.balls,
          player_ranking.innings,
          # (sprintf("%.2f",(1.0 * player_ranking.balls) / player_ranking.innings) if player_ranking.innings.to_i > 0),
          (player_ranking.discipline.send(:"#{Discipline::KEY_MAPPINGS[player_ranking.discipline.root.name][:ranking][:formula]}", player_ranking, {v1: player_ranking.balls, v2: player_ranking.innings}) if Discipline::KEY_MAPPINGS[player_ranking.discipline.root.name].andand[:ranking].present?),
          player_ranking.hs,
          sprintf("%.2f", player_ranking.bed.to_f),
          sprintf("%.2f", player_ranking.btg.to_f),
          player_ranking.discipline.class_from_accumulated_result(player_ranking),
          player_ranking.g,
          player_ranking.v,
          # ((sprintf("%.2f",(100.0 * player_ranking.g.to_f / (player_ranking.v.to_f + player_ranking.g.to_f))) + '%') if (player_ranking.g.to_i > 0) && (player_ranking.g.to_i > 0)),
          (player_ranking.discipline.send(:"#{Discipline::KEY_MAPPINGS[player_ranking.discipline.root.name].andand[:ranking].andand[:formula]}", player_ranking, {v1: player_ranking.g, v2: player_ranking.v})[0] if Discipline::KEY_MAPPINGS[player_ranking.discipline.root.name].andand[:ranking].present?),
          player_ranking.sets,
          player_ranking.sp_g,
          player_ranking.sp_v,
          # ((sprintf("%.2f",(100.0 * player_ranking.sp_g.to_f / (player_ranking.sp_v.to_f + player_ranking.sp_g.to_f))) + '%') if (player_ranking.sp_v.to_f + player_ranking.sp_g.to_f) > 0),
          (player_ranking.discipline.send(:"#{Discipline::KEY_MAPPINGS[player_ranking.discipline.root.name][:ranking][:formula]}", player_ranking, {v1: player_ranking.sp_g, v2: player_ranking.sp_v}) if Discipline::KEY_MAPPINGS[player_ranking.discipline.root.name].andand[:ranking].present?),
          # player_ranking.player_class,
          # player_ranking.p_player_class,
          # player_ranking.pp_player_class,
          # player_ranking.p_gd,
          # player_ranking.pp_gd,
          # player_ranking.org_level,
          # player_ranking.status,
          player_ranking.t_ids.map { |t_id| link_to(t_id, @view.tournament_path(id: t_id)) }.join(", ").html_safe,
      # "#{(link_to image_tag("ansehen.gif", :width => 26, :height => 22, :border => 0), player_ranking) + " " +
      #     (link_to image_tag("bearbeiten.gif", :width => 26, :height => 22, :border => 0), @view.edit_player_ranking_path(player_ranking)) + " " +
      #     (link_to image_tag("loeschen.gif", :width => 26, :height => 22, :border => 0), player_ranking, method: :delete, data: {confirm: 'Are you sure?'})}"
      ]
    end
  end

  def player_rankings
    ret = @player_rankings ||= fetch_player_rankings
  end


  def fetch_player_rankings
    rankings = PlayerRanking.order(order).joins(:region, :player, :season, :discipline).where("player_rankings.innings > 0")

    rankings = rankings.select("*")

    PlayerRanking::COLUMN_NAMES.each do |ext_name, int_name|
      if int_name =~ / as /
        parts = int_name.split(" as ").map(&:strip)
        tempname = parts[-1]
        term = parts[0..-2].join(" as ")
        rankings = rankings.select("#{term} as #{tempname}")
      end
    end
    if params[:sSearch].present?
      rankings = apply_filters(rankings, PlayerRanking::COLUMN_NAMES, "(regions.shortname ilike :search) or (disciplines.name ilike :search) or (players.lastname||', '||players.firstname ilike :search)")
    end
    rankings = rankings.page(page).per(per_page)
    rankings
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
    columns = PlayerRanking::COLUMN_NAMES.map do |k, v|
      cv = (
      if v =~ / as /
        v.split(" as ").map(&:strip)[-1]
      else
        v
      end)
      ; cv
    end
    columns
    if params[:"iSortCol_#{i}"].present?
      ret = columns[params[:"iSortCol_#{i}"].to_i]
    end
    ret
  end

  def sort_direction(i)
    params[:"sSortDir_#{i}"] == "desc" ? "desc" : "asc"
  end
end