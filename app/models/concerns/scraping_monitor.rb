# frozen_string_literal: true

# ScrapeMonitor: Monitoring & Statistiken für Scraping-Operationen
#
# Tracked:
# - Exceptions & Errors
# - Create/Update/Delete Statistiken
# - Performance (Laufzeit)
# - Code-Überdeckung (welche Methoden wurden aufgerufen)
#
# Usage:
#   ScrapeMonitor.track("tournament_scraping") do
#     tournament.scrape_single_tournament_public
#   end

module ScrapeMonitor
  extend ActiveSupport::Concern
  
  class_methods do
    # Hauptmethode: Trackt eine Scraping-Operation
    def track_scraping(operation_name, &block)
      monitor = ScrapingMonitor.new(operation_name, self.name)
      monitor.run(&block)
    end
  end
  
  # Instance-Methode: Trackt Scraping für einzelnes Objekt
  def track_scraping(operation_name, &block)
    monitor = ScrapingMonitor.new(operation_name, "#{self.class.name}[#{id}]")
    monitor.run(&block)
  end
end

# ScrapingMonitor: Sammelt Statistiken während des Scrapings
class ScrapingMonitor
  attr_reader :operation, :context, :stats, :errors
  
  def initialize(operation, context = nil)
    @operation = operation
    @context = context
    @start_time = Time.current
    @stats = {
      created: 0,
      updated: 0,
      deleted: 0,
      unchanged: 0,
      errors: 0
    }
    @errors = []
    @method_calls = []
  end
  
  def run(&block)
    Rails.logger.info "▶️  ScrapeMonitor: Starting #{operation} (#{context})"
    
    # Track DB changes
    track_database_changes do
      # Track exceptions
      begin
        result = block.call(self)
        log_success
        result
      rescue => e
        log_error(e)
        raise  # Re-raise nach Logging
      end
    end
  ensure
    log_summary
  end
  
  # Callback: Wird aufgerufen wenn Record erstellt wurde
  def record_created(record)
    @stats[:created] += 1
    Rails.logger.debug "  ✅ Created: #{record.class.name}[#{record.id}]"
  end
  
  # Callback: Wird aufgerufen wenn Record aktualisiert wurde
  def record_updated(record)
    @stats[:updated] += 1
    Rails.logger.debug "  🔄 Updated: #{record.class.name}[#{record.id}]"
  end
  
  # Callback: Wird aufgerufen wenn Record gelöscht wurde
  def record_deleted(record)
    @stats[:deleted] += 1
    Rails.logger.debug "  ❌ Deleted: #{record.class.name}[#{record.id}]"
  end
  
  # Callback: Wird aufgerufen wenn Record unverändert blieb
  def record_unchanged(record)
    @stats[:unchanged] += 1
    Rails.logger.debug "  ⏭️  Unchanged: #{record.class.name}[#{record.id}]"
  end
  
  # Callback: Wird aufgerufen bei Error
  def record_error(record, error)
    @stats[:errors] += 1
    @errors << { record: record, error: error }
    Rails.logger.error "  ⚠️  Error: #{record.class.name}[#{record&.id}] - #{error.message}"
  end
  
  # Track welche Methode aufgerufen wurde (für Code-Überdeckung)
  def track_method(method_name)
    @method_calls << method_name unless @method_calls.include?(method_name)
  end
  
  private
  
  def track_database_changes(&block)
    # Zähle DB-Operationen via ActiveSupport::Notifications
    created_count = 0
    updated_count = 0
    deleted_count = 0
    
    # Subscribe to SQL events
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
      sql = payload[:sql]
      
      # Zähle INSERT/UPDATE/DELETE
      created_count += 1 if sql =~ /^INSERT INTO/
      updated_count += 1 if sql =~ /^UPDATE/
      deleted_count += 1 if sql =~ /^DELETE FROM/
    end
    
    begin
      block.call
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
      
      # Aktualisiere Stats (falls nicht manuell getrackt)
      @stats[:created] = created_count if @stats[:created] == 0
      @stats[:updated] = updated_count if @stats[:updated] == 0
      @stats[:deleted] = deleted_count if @stats[:deleted] == 0
    end
  end
  
  def log_success
    duration = Time.current - @start_time
    Rails.logger.info "✅ ScrapeMonitor: #{operation} completed in #{duration.round(2)}s"
  end
  
  def log_error(error)
    duration = Time.current - @start_time
    @stats[:errors] += 1
    @errors << { context: @context, error: error }
    
    Rails.logger.error "❌ ScrapeMonitor: #{operation} failed after #{duration.round(2)}s"
    Rails.logger.error "   Error: #{error.class.name}: #{error.message}"
    Rails.logger.error "   Backtrace: #{error.backtrace.first(3).join("\n   ")}"
  end
  
  def log_summary
    duration = Time.current - @start_time
    
    Rails.logger.info "📊 ScrapeMonitor Summary: #{operation}"
    Rails.logger.info "   Duration: #{duration.round(2)}s"
    Rails.logger.info "   Created:   #{@stats[:created]}"
    Rails.logger.info "   Updated:   #{@stats[:updated]}"
    Rails.logger.info "   Deleted:   #{@stats[:deleted]}"
    Rails.logger.info "   Unchanged: #{@stats[:unchanged]}"
    Rails.logger.info "   Errors:    #{@stats[:errors]}"
    
    if @method_calls.any?
      Rails.logger.info "   Methods called: #{@method_calls.join(', ')}"
    end
    
    # Error Details
    if @errors.any?
      Rails.logger.error "⚠️  Errors during #{operation}:"
      @errors.each_with_index do |error_info, i|
        Rails.logger.error "   #{i + 1}. #{error_info[:error].class.name}: #{error_info[:error].message}"
      end
    end
    
    # Speichere in Datenbank für langfristige Auswertung
    save_to_database(duration)
  end
  
  def save_to_database(duration)
    # Speichert Monitoring-Daten in scraping_logs Tabelle
    ScrapingLog.create!(
      operation: @operation,
      context: @context,
      duration: duration,
      created_count: @stats[:created],
      updated_count: @stats[:updated],
      deleted_count: @stats[:deleted],
      unchanged_count: @stats[:unchanged],
      error_count: @stats[:errors],
      errors_json: @errors.map { |e| 
        { 
          context: e[:context] || e[:record]&.class&.name,
          error: {
            class: e[:error].class.name,
            message: e[:error].message,
            backtrace: e[:error].backtrace&.first(3)
          }
        }
      }.to_json,
      executed_at: @start_time
    )
  rescue => e
    Rails.logger.warn "Could not save scraping stats: #{e.message}"
  end
end
