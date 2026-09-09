# frozen_string_literal: true

# ActionCable Connection Management
# Handles force reconnect after server restart

Rails.application.config.after_initialize do
  # Nur echte Server-Boots duerfen broadcasten. Alles andere ueberspringen:
  # Konsole, rake-Tasks UND `rails runner`.
  #
  # `rails runner` fehlte hier und hat am 2026-09-09 waehrend einer als read-only geplanten
  # Prod-Messung (Plan 47-03) allen Scoreboards ein force_reconnect geschickt
  # (production.log 10:46:58). Der Fall trifft nur Runner, die laenger als die 15 Sekunden
  # unten leben — also Mess- und Wartungslaeufe.
  #
  # WARUM `Rails::Command::RunnerCommand` — empirisch geprueft, bitte nicht "vereinfachen":
  #   * In `rails runner` ist $PROGRAM_NAME nur "bin/rails" und ARGV bereits leer, die
  #     rake-Pruefung unten greift also nicht.
  #   * `defined?(Puma)` taugt NICHT als Unterscheider: Bundler.require definiert die Konstante
  #     in JEDEM Prozess, auch im Runner.
  #   * Ein Positiv-Test ("laeuft als Server") ist nicht moeglich: Produktion startet
  #     `puma -C config/puma.rb`, dort ist `Rails::Server` ebenfalls nil. Die Bedingung
  #     umzudrehen wuerde den Gutfall stilllegen — der belegt funktioniert
  #     (production.log 13:25:30, genau ein Broadcast je Deploy aus dem Puma-Master).
  #
  # SKIP_FORCE_RECONNECT ist der Notausgang fuer alles, was diese Liste nicht kennt — damit ein
  # neuer Fall keinen Deploy braucht.
  next if ENV["SKIP_FORCE_RECONNECT"] == "true"
  next if defined?(Rails::Console) ||
    defined?(Rails::Command::RunnerCommand) ||
    File.basename($PROGRAM_NAME) == "rake"
  
  # Only run in production or if explicitly enabled
  force_reconnect = ENV['FORCE_RECONNECT_ON_BOOT'] == 'true'
  
  if Rails.env.production? || force_reconnect
    # Wait for server to be fully initialized
    Thread.new do
      # Wait 15 seconds for:
      # - All services to be ready
      # - Redis connection to be established
      # - ActionCable server to be mounted
      sleep 15
      
      begin
        Rails.logger.info "🔄 Sending force reconnect to all clients (server restarted)"
        
        # Broadcast force reconnect
        TableMonitorChannel.force_reconnect(reason: "server_restarted")
        
        Rails.logger.info "✅ Force reconnect broadcast sent successfully"
      rescue StandardError => e
        Rails.logger.error "❌ Failed to send force reconnect: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end
end


