# frozen_string_literal: true

# Plan 41-04 Task 2 (D-41-B): Strukturiertes Logging jedes ActionMailer-Delivery-Versuchs.
# Standard-Rails-API (register_observer / register_interceptor) — kein Monkey-Patching.
# Tagged-Logger 'MAILER' macht grep im production.log einfach:
#   grep '\[MAILER\]' log/production.log | grep FAIL
#
# Bounce-Handling: Permanente SMTP-Fehler (Net::SMTPFatalError) werden im
# DeviseMailJob mit discard_on verworfen + hier ueber delivery_failed-Hook
# geloggt (Audit-Trail fuer Ops).
class MailDeliveryObserver
  def self.delivered_email(message)
    Rails.logger.tagged("MAILER") do
      Rails.logger.info(
        "delivered to=#{Array(message.to).join(",")} " \
        "subject=#{message.subject&.gsub(/\s+/, " ")} " \
        "from=#{Array(message.from).join(",")}"
      )
    end
  rescue => e
    Rails.logger.error "[MAILER] Observer crashed: #{e.class}: #{e.message}"
  end

  # Wird von ActionMailer::DeliveryMethods (synchron-Path) bei Exception aufgerufen.
  # Bei deliver_later (DeviseMailJob) faengt retry_on/discard_on ab; trotzdem
  # registrieren wir hier den Hook fuer ggf. nicht-Devise-Mailer (UploadMailer etc.).
  def self.delivery_failed(message, error)
    Rails.logger.tagged("MAILER") do
      Rails.logger.error(
        "FAILED to=#{Array(message&.to).join(",")} " \
        "subject=#{message&.subject&.gsub(/\s+/, " ")} " \
        "error=#{error.class}: #{error.message}"
      )
    end
  rescue => e
    Rails.logger.error "[MAILER] Failure-Observer crashed: #{e.class}: #{e.message}"
  end
end

ActionMailer::Base.register_observer(MailDeliveryObserver)
