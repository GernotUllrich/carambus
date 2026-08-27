# frozen_string_literal: true

# Terminkalender einer Region: Turniere und Liga-Spieltage gemeinsam.
#
# Bewusst OHNE Auth-Filter — die Seite zeigt nichts, was `tournaments#index` und `leagues#index`
# nicht schon oeffentlich zeigen (leagues_controller.rb nimmt `index`/`show` ausdruecklich aus).
#
# Alle Filter stehen im URL, damit ein Kalenderblatt teilbar ist: `month`, `branch`, `dbu`, `view`.
class CalendarsController < ApplicationController
  VIEW_MODES = %w[agenda grid].freeze

  def show
    @region = Region.find(params[:region_id])
    @month = parse_month(params[:month])
    @from = @month.beginning_of_month
    @to = @month.end_of_month

    @branch_name = params[:branch].presence
    @include_dbu = params[:dbu] != "0"
    @view_mode = VIEW_MODES.include?(params[:view]) ? params[:view] : "agenda"

    @entries = Calendar::Query.new(
      region: @region, from: @from, to: @to,
      branch_name: @branch_name, include_dbu: @include_dbu
    ).call

    @branch_names = Branch.order(:name).pluck(:name)
    @season = Season.season_from_date(@from)
  end

  private

  # "YYYY-MM" oder leer. Unsinn faellt auf den laufenden Monat zurueck, statt zu werfen —
  # ein kaputter Link soll eine Seite zeigen, keinen Fehler.
  def parse_month(raw)
    return Date.current.beginning_of_month if raw.blank?

    Date.strptime(raw.to_s, "%Y-%m").beginning_of_month
  rescue ArgumentError, TypeError
    Date.current.beginning_of_month
  end
end
