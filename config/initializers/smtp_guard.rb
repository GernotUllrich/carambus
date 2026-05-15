# frozen_string_literal: true

# Plan 41-04 Task 2 (D-41-B): Fail-Fast bei fehlendem SMTP_USERNAME / SMTP_PASSWORD
# in Production. Verhindert dass Production-App mit kaputtem Devise-Mailer startet
# — Devise-Mails (confirmation, reset_password, password_change) wuerden sonst still
# scheitern bzw. mit Fallback-Sender "no-reply@carambus.de" rausgehen, was Gmail-SMTP-Auth
# zurueckweist (SPF/DKIM-Mismatch).
#
# Wirkung: bei Production-Boot ohne ENV crashed der Rails-Process sofort mit
# klarer Fehler-Message — viel besser als nachher silently kaputte Mails.
if Rails.env.production?
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
