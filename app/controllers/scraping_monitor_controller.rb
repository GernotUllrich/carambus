# frozen_string_literal: true

# Controller für Scraping-Monitor Dashboard
# Route: /scraping_monitor

class ScrapingMonitorController < ApplicationController
  # Nur für Admin/Developer
  before_action :require_admin

  def index
    @time_range = params[:days]&.to_i || 7
    @since = @time_range.days.ago

    # Alle Operations mit Stats
    @operations_stats = ScrapingLog.all_operations_stats(since: @since)

    # Letzte Logs
    @recent_logs = ScrapingLog.where("executed_at >= ?", @since)
      .order(executed_at: :desc)
      .limit(50)

    # Anomalien
    @anomalies = ScrapingLog.check_anomalies

    # Charts Data
    @chart_data = prepare_chart_data(@time_range)
  end

  def operation
    @operation = params[:id]
    @time_range = params[:days]&.to_i || 30
    @since = @time_range.days.ago

    @stats = ScrapingLog.stats_for(@operation, since: @since)

    @logs = ScrapingLog.by_operation(@operation)
      .where("executed_at >= ?", @since)
      .order(executed_at: :desc)
      .limit(100)

    @chart_data = prepare_operation_chart_data(@operation, @time_range)
  end

  private

  def require_admin
    # TODO: Implement authentication
    # return unless current_user&.admin?
    # redirect_to root_path, alert: "Not authorized"
  end

  def prepare_chart_data(days)
    logs = ScrapingLog.where("executed_at >= ?", days.days.ago)
      .order(:executed_at)

    # Group by day
    by_day = logs.group_by { |log| log.executed_at.to_date }

    {
      dates: by_day.keys.map(&:to_s),
      created: by_day.values.map { |logs| logs.sum(&:created_count) },
      updated: by_day.values.map { |logs| logs.sum(&:updated_count) },
      errors: by_day.values.map { |logs| logs.sum(&:error_count) }
    }
  end

  def prepare_operation_chart_data(operation, days)
    logs = ScrapingLog.by_operation(operation)
      .where("executed_at >= ?", days.days.ago)
      .order(:executed_at)

    {
      timestamps: logs.pluck(:executed_at).map { |t| t.strftime("%Y-%m-%d %H:%M") },
      durations: logs.pluck(:duration).map { |d| d&.round(2) || 0 },
      created: logs.pluck(:created_count),
      updated: logs.pluck(:updated_count),
      errors: logs.pluck(:error_count)
    }
  end
end
