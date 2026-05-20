# frozen_string_literal: true

# Plan 41-04 Task 2 (D-41-B): Async-Versand aller Devise-Mails mit Retry-Logik.
#
# transient Errors (retry_on):
#   - Net::SMTPAuthenticationError: Gmail-Auth temporaer fehlgeschlagen (z.B. App-Pw rotated,
#     Gmail-Rate-Limit-Window) → bis zu 3 Versuche mit exponential backoff
#   - Net::SMTPServerBusy: Gmail-MX temporaer ueberlastet → bis zu 5 Versuche
#
# permanente Errors (discard_on, Bounce-Handling):
#   - Net::SMTPFatalError: Empfaenger-Adresse ungueltig / Permanent-Bounce →
#     Job aufgeben, Logging via Observer / Rails.logger; keine Retries.
#
# User#send_devise_notification (Override im User-Modell) enqueued statt deliver_now.
class DeviseMailJob < ApplicationJob
  queue_as :mailers

  retry_on Net::SMTPAuthenticationError, wait: :polynomially_longer, attempts: 3
  retry_on Net::SMTPServerBusy, wait: :polynomially_longer, attempts: 5

  # Bounce-Handling: permanent fatal → log + verwerfen.
  discard_on Net::SMTPFatalError do |job, error|
    Rails.logger.tagged("MAILER") do
      Rails.logger.error(
        "DISCARD permanent SMTP-Fatal — Job=#{job.class} args=#{job.arguments.inspect} " \
        "error=#{error.class}: #{error.message}"
      )
    end
  end

  # perform(mailer_class, notification_method, record_class, record_id, *raw_args)
  # Devise uebergibt User-Record + Token-Args; wir serialisieren record als id und
  # finden ihn wieder, damit ActiveJob's GlobalID-Serialisierung sauber laeuft.
  def perform(mailer_class, notification, record_class, record_id, *args)
    record = record_class.constantize.find_by(id: record_id)
    return if record.nil? # User wurde inzwischen geloescht — nichts zu tun

    mailer_class.constantize.send(notification, record, *args).deliver_now
  end
end
