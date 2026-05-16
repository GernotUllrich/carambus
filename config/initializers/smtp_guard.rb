# frozen_string_literal: true

# Plan 41-04 Task 2 (D-41-B): Fail-Fast bei fehlendem SMTP_USERNAME / SMTP_PASSWORD
# beim Web-Server- oder Worker-Boot in Production. Verhindert dass Production-App
# mit kaputtem Devise-Mailer startet — Devise-Mails (confirmation, reset_password,
# password_change) wuerden sonst still scheitern bzw. mit Fallback-Sender
# "no-reply@carambus.de" rausgehen, was Gmail-SMTP-Auth zurueckweist (SPF/DKIM-Mismatch).
#
# Wirkung: beim WEB-SERVER- oder SIDEKIQ-Boot ohne ENV crashed der Rails-Process
# sofort mit klarer Fehler-Message. NICHT beim Deploy-Setup (rake db:migrate,
# assets:precompile, db:seed, rails console, rails runner, generators) — diese
# Tasks senden keine Mails und sollen ohne SMTP-Creds laufbar bleiben (Hot-Fix
# nach Phase 41 Production-Deploy-Bruch von carambus_nbv 2026-05-16).
if Rails.env.production?
  # Detection ueber empirisch bewaehrte Signale (verifiziert mit File-Trace,
  # carambus_nbv-Tree, 2026-05-16):
  #
  #   ✓ `defined?(Rails::Server)`  ist gesetzt beim `bin/rails server` (Rails-Command-Wrapper
  #     setzt es vor Initializer-Load). NICHT gesetzt bei rake/console/runner.
  #   ✓ `File.basename($PROGRAM_NAME) == "puma"` greift bei direktem `bundle exec puma`
  #     (Capistrano startet Puma so via systemd/initd ohne `bin/rails`).
  #   ✓ `File.basename($PROGRAM_NAME) == "sidekiq"` greift bei `bundle exec sidekiq`.
  #
  # NICHT verlassbar:
  #   ✗ `defined?(::Puma::*)` — Bundler eager-loaded ALLE Gemfile-Gems, also auch bei
  #      `rake db:migrate` ist `Puma::Server` als "constant" definiert (false positive).
  #   ✗ `ARGV.first == "server"` — Rails-Command-Dispatcher hat das Subkommando "server"
  #      bereits aus ARGV entfernt, bevor Initializer-Load passiert.
  #
  # Greift bei:    bin/rails server, bundle exec puma, bundle exec sidekiq
  # Skipped bei:   rake db:migrate, rails console, rails runner, rails generators
  basename = File.basename($PROGRAM_NAME)
  server_boot = defined?(Rails::Server) ||
                basename == "puma" ||
                basename == "sidekiq"

  if server_boot
    missing = []
    missing << "SMTP_USERNAME" if ENV["SMTP_USERNAME"].blank?
    missing << "SMTP_PASSWORD" if ENV["SMTP_PASSWORD"].blank?

    if missing.any?
      raise <<~MSG
        FATAL: SMTP-ENV nicht gesetzt — Devise-Mails wuerden Production-Boot brechen.
        Fehlend: #{missing.join(", ")}
        Devise.mailer_sender benoetigt SMTP_USERNAME, Gmail-SMTP-Auth benoetigt
        SMTP_USERNAME + SMTP_PASSWORD.
        Aborting startup. (config/initializers/smtp_guard.rb)
      MSG
    end
  end
end
