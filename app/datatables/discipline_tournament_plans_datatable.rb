class DisciplineTournamentPlansDatatable
  include FiltersHelper
  delegate :params, :h, :link_to, :image_tag, :mail_to, :number_to_currency, to: :@view

  def initialize(view, discipline_tournament_plans)
    @view = view
    @discipline_tournament_plans = discipline_tournament_plans
  end

  def as_json(options = {})
    {
        sEcho: params[:sEcho].to_i,
        iTotalRecords: DisciplineTournamentPlan.count,
        iTotalDisplayRecords: discipline_tournament_plans.total_count,
        aaData: data
    }
  end

  private

  def data
    discipline_tournament_plans.map do |discipline_tournament_plan|
      [
          link_to(discipline_tournament_plan.discipline.name, @view.discipline_path(discipline_tournament_plan.discipline)),
          link_to(discipline_tournament_plan.tournament_plan.name, @view.tournament_plan_path(discipline_tournament_plan.tournament_plan)),
          discipline_tournament_plan.points,
          discipline_tournament_plan.innings,
          discipline_tournament_plan.players,
          discipline_tournament_plan.player_class,
          "#{(link_to image_tag("ansehen.gif", :width => 26, :height => 22, :border => 0), discipline_tournament_plan) + " " +
              (link_to image_tag("bearbeiten.gif", :width => 26, :height => 22, :border => 0), @view.edit_discipline_tournament_plan_path(discipline_tournament_plan)) + " " +
              (link_to image_tag("loeschen.gif", :width => 26, :height => 22, :border => 0), discipline_tournament_plan, method: :delete, data: {confirm: 'Are you sure?'})}"
      ]
    end
  end

  def discipline_tournament_plans
    @discipline_tournament_plans ||= fetch_discipline_tournament_plans
  end

  def fetch_discipline_tournament_plans
    discipline_tournament_plans = DisciplineTournamentPlan.joins(:discipline, :tournament_plan).order(order)
    if params[:sSearch].present?
      discipline_tournament_plans = apply_filters(discipline_tournament_plans, DisciplineTournamentPlan::COLUMN_NAMES, "(disciplines.name ilike :search) or (tournament_plans.name ilike :search) or (discipline_tournament_plans.player_class ilike :search) or (discipline_tournament_plans.players = :isearch)")
    end
    discipline_tournament_plans = discipline_tournament_plans.page(page).per(per_page)
    discipline_tournament_plans
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
    columns = DisciplineTournamentPlan::COLUMN_NAMES.values
    columns[params[:"iSortCol_#{i}"].to_i] if params[:"iSortCol_#{i}"].present?
  end

  def sort_direction(i)
    params[:"sSortDir_#{i}"] == "desc" ? "desc" : "asc"
  end
end