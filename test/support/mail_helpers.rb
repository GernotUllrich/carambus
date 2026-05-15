# frozen_string_literal: true

# D-41-A Layer-3+4-Helper: extrahiert Devise-Tokens aus generierten Mail-Bodies.
# In Tests via `include MailHelpers` (siehe test_helper.rb — included in
# ActionMailer::TestCase + ActionDispatch::IntegrationTest + ApplicationSystemTestCase).
module MailHelpers
  def last_email
    ActionMailer::Base.deliveries.last
  end

  def clear_mail_queue
    ActionMailer::Base.deliveries.clear
  end

  # Extrahiert vollständige Confirmation-URL inkl. confirmation_token aus Mail-Body.
  # Nutzbar in System-Tests für Click-Through-Flow (Plan 41-05).
  def extract_confirmation_url(mail = last_email)
    body = mail.body.to_s
    match = body.match(%r{https?://[^\s"'<>]+/confirmation\?[^\s"'<>]+})
    match&.to_s
  end

  # Extrahiert vollständige Reset-Password-URL inkl. reset_password_token aus Mail-Body.
  def extract_reset_password_url(mail = last_email)
    body = mail.body.to_s
    match = body.match(%r{https?://[^\s"'<>]+/password/edit\?[^\s"'<>]+})
    match&.to_s
  end
end
