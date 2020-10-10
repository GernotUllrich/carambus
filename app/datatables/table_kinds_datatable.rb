class TableKindsDatatable
  include FiltersHelper
  delegate :params, :h, :link_to, :image_tag, :mail_to, :number_to_currency, to: :@view

  def initialize(view, table_kinds)
    @view = view
    @table_kinds = table_kinds
  end

  def as_json(options = {})
    {
        sEcho: params[:sEcho].to_i,
        iTotalRecords: TableKind.count,
        iTotalDisplayRecords: table_kinds.total_count,
        aaData: data
    }
  end

  private

  def data
    table_kinds.map do |table_kind|
      [
          link_to(table_kind.name, @view.table_kind_path(table_kind)),
          table_kind.short,
          table_kind.measures,
          "#{(link_to image_tag("ansehen.gif", :width => 26, :height => 22, :border => 0), table_kind) + " " +
              (link_to image_tag("bearbeiten.gif", :width => 26, :height => 22, :border => 0), @view.edit_table_kind_path(table_kind)) + " " +
              (link_to image_tag("loeschen.gif", :width => 26, :height => 22, :border => 0), table_kind, method: :delete, data: {confirm: 'Are you sure?'})}"
      ]
    end
  end

  def table_kinds
    @table_kinds ||= fetch_table_kinds
  end

  def fetch_table_kinds
    table_kinds = TableKind.order(order)
    if params[:sSearch].present?
      table_kinds = apply_filters(table_kinds, TableKind::COLUMN_NAMES, "(table_kinds.name ilike :search) or (table_kinds.shortname ilike :search)")
    end
    table_kinds = table_kinds.page(page).per(per_page)
    table_kinds
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
    columns = TableKind::COLUMN_NAMES.values
    columns[params[:"iSortCol_#{i}"].to_i] if params[:"iSortCol_#{i}"].present?
  end

  def sort_direction(i)
    params[:"sSortDir_#{i}"] == "desc" ? "desc" : "asc"
  end
end