class SeedingsDatatable
  include FiltersHelper
  delegate :params, :h, :link_to, :image_tag, :mail_to, :number_to_currency, to: :@view

  def initialize(view, seedings)
    @view = view
    @seedings = seedings
  end

  def as_json(options = {})
    {
        sEcho: params[:sEcho].to_i,
        iTotalRecords: Seeding.count,
        iTotalDisplayRecords: seedings.total_count,
        aaData: data
    }
  end

  private

  def data
    seedings.map do |seeding|
      [
          link_to(seeding.player.fullname, @view.player_path(seeding.player)),
          link_to(seeding.tournament.title, @view.tournament_path(seeding.tournament)) + " (BA #{link_to(seeding.tournament.ba_id, "https://#{seeding.tournament.region.shortname.downcase}.billardarea.de/cms_#{seeding.tournament.single_or_league}/#{seeding.tournament.plan_or_show}/#{seeding.tournament.ba_id}")})".html_safe,
          link_to(seeding.tournament.discipline.name, @view.discipline_path(seeding.tournament.discipline)),
          seeding.tournament.date.to_date,
          (link_to("#{seeding.tournament.season.name}", @view.season_path(seeding.tournament.season))),
          seeding.ba_state,
          seeding.position,
          link_to(Seeding.result_display(seeding), @view.seeding_path(seeding)),
          "#{(link_to image_tag("ansehen.gif", :width => 26, :height => 22, :border => 0), seeding) + " " +
              (link_to image_tag("bearbeiten.gif", :width => 26, :height => 22, :border => 0), @view.edit_seeding_path(seeding)) + " " +
              (link_to image_tag("loeschen.gif", :width => 26, :height => 22, :border => 0), seeding, method: :delete, data: {confirm: 'Are you sure?'})}"
      ]
    end
  end

  def seedings
    @seedings ||= fetch_seedings
  end

  def fetch_seedings
    seedings = Seeding.joins(:player, :tournament => :season).order(order)
    if params[:sSearch].present?
      seedings = apply_filters(seedings, Seeding::COLUMN_NAMES, "(tournaments.title ilike :search) or (players.lastname||', '||players.firstname ilike :search) or (seasons.name ilike :search) or (seedings.status ilike :search)")
    end
    seedings = seedings.page(page).per(per_page)
    seedings
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
    columns = Seeding::COLUMN_NAMES.values
    columns[params[:"iSortCol_#{i}"].to_i] if params[:"iSortCol_#{i}"].present?
  end

  def sort_direction(i)
    params[:"sSortDir_#{i}"] == "desc" ? "desc" : "asc"
  end
end