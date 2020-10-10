class DisciplinesDatatable
  include FiltersHelper
  delegate :params, :h, :link_to, :image_tag, :mail_to, :number_to_currency, to: :@view

  def initialize(view, disciplines)
    @view = view
    @disciplines = disciplines
  end

  def as_json(options = {})
    {
        sEcho: params[:sEcho].to_i,
        iTotalRecords: Discipline.count,
        iTotalDisplayRecords: disciplines.total_count,
        aaData: data
    }
  end

  private

  def data
    disciplines.map do |discipline|
      [

          link_to(discipline.name, @view.discipline_path(discipline)),
          (link_to(discipline.super_discipline.name, @view.discipline_path(discipline.super_discipline)) if discipline.super_discipline.present?),
          (link_to(discipline.table_kind.name, @view.table_kind_path(discipline.table_kind)) if discipline.table_kind.present?),
          "#{(link_to image_tag("ansehen.gif", :width => 26, :height => 22, :border => 0), discipline) + " " +
              (link_to image_tag("bearbeiten.gif", :width => 26, :height => 22, :border => 0), @view.edit_discipline_path(discipline)) + " " +
              (link_to image_tag("loeschen.gif", :width => 26, :height => 22, :border => 0), discipline, method: :delete, data: {confirm: 'Are you sure?'})}"
      ]
    end
  end

  def disciplines
    @disciplines ||= fetch_disciplines
  end

  def fetch_disciplines
    disciplines = Discipline.includes(:table_kind).joins("LEFT JOIN disciplines sup ON disciplines.super_discipline_id = sup.id").order(order)
    if params[:sSearch].present?
      disciplines = apply_filters(disciplines, Discipline::COLUMN_NAMES, "(disciplines.name ilike :search) or (table_kinds.name ilike :search) or (disciplines.table_size ilike :search)")
    end
    disciplines = disciplines.page(page).per(per_page)
    disciplines
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
    columns = Discipline::COLUMN_NAMES.values
    columns[params[:"iSortCol_#{i}"].to_i] if params[:"iSortCol_#{i}"].present?
  end

  def sort_direction(i)
    params[:"sSortDir_#{i}"] == "desc" ? "desc" : "asc"
  end
end