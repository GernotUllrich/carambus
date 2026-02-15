# frozen_string_literal: true

# ScrapingLog: Persistiert Monitoring-Daten von Scraping-Operationen
#
# Ermöglicht:
# - Langfristige Auswertung
# - Trend-Analyse
# - Alert bei ungewöhnlichen Patterns
# - Performance-Monitoring

class ScrapingLog < ApplicationRecord
  # Validations
  validates :operation, presence: true
  validates :executed_at, presence: true
  
  # Scopes
  scope :recent, -> { order(executed_at: :desc).limit(100) }
  scope :by_operation, ->(op) { where(operation: op) }
  scope :with_errors, -> { where("error_count > 0") }
  scope :today, -> { where("executed_at >= ?", Time.current.beginning_of_day) }
  scope :last_week, -> { where("executed_at >= ?", 1.week.ago) }
  
  # Parse errors_json
  def errors_parsed
    return [] if errors_json.blank?
    JSON.parse(errors_json)
  rescue JSON::ParserError
    []
  end
  
  # Total operations count
  def total_operations
    created_count + updated_count + deleted_count + unchanged_count
  end
  
  # Success rate
  def success_rate
    return 100.0 if total_operations.zero?
    ((total_operations - error_count).to_f / total_operations * 100).round(1)
  end
  
  # Statistiken für Operation
  def self.stats_for(operation, since: 1.week.ago)
    logs = by_operation(operation).where("executed_at >= ?", since)
    
    {
      total_runs: logs.count,
      avg_duration: logs.average(:duration)&.round(2) || 0,
      total_created: logs.sum(:created_count),
      total_updated: logs.sum(:updated_count),
      total_deleted: logs.sum(:deleted_count),
      total_errors: logs.sum(:error_count),
      last_run: logs.maximum(:executed_at),
      success_rate: calculate_success_rate(logs)
    }
  end
  
  # Alle Operationen mit Statistiken
  def self.all_operations_stats(since: 1.week.ago)
    operations = where("executed_at >= ?", since).distinct.pluck(:operation)
    
    operations.map do |op|
      { operation: op }.merge(stats_for(op, since: since))
    end.sort_by { |s| s[:total_runs] }.reverse
  end
  
  # Prüfe auf Anomalien (z.B. ungewöhnlich viele Errors)
  def self.check_anomalies(threshold: 0.1)
    anomalies = []
    
    all_operations_stats.each do |stats|
      # Mehr als 10% Errors?
      if stats[:success_rate] < (100 - threshold * 100)
        anomalies << {
          operation: stats[:operation],
          issue: "High error rate: #{100 - stats[:success_rate]}%",
          details: stats
        }
      end
      
      # Ungewöhnlich lange Laufzeit?
      if stats[:avg_duration] > 300  # 5 Minuten
        anomalies << {
          operation: stats[:operation],
          issue: "Slow performance: #{stats[:avg_duration]}s",
          details: stats
        }
      end
    end
    
    anomalies
  end
  
  # Bereinige alte Logs (älter als X Tage)
  def self.cleanup_old_logs(keep_days: 90)
    cutoff = keep_days.days.ago
    deleted = where("executed_at < ?", cutoff).delete_all
    
    Rails.logger.info "🧹 Cleaned up #{deleted} old scraping logs (older than #{keep_days} days)"
    deleted
  end
  
  private
  
  def self.calculate_success_rate(logs)
    return 100.0 if logs.empty?
    
    total_ops = logs.sum(:created_count) + logs.sum(:updated_count) + 
                logs.sum(:deleted_count) + logs.sum("COALESCE(unchanged_count, 0)")
    total_errors = logs.sum(:error_count)
    
    return 100.0 if total_ops.zero?
    ((total_ops - total_errors).to_f / total_ops * 100).round(1)
  end
end
