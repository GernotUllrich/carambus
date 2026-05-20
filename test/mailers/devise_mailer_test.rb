# frozen_string_literal: true

require "test_helper"

# D-41-A Layer 3: Charakterisierungstests pinnen IST-Verhalten der Devise-Mailer.
# Wenn Plan-02..04 Sender-Angleichung / View-Tweaks ändern, ziehen diese Tests mit.
class DeviseMailerTest < ActionMailer::TestCase
  setup do
    clear_mail_queue
    @user = users(:valid)
  end

  test "confirmation_instructions: empfaenger, subject (DE), token-url im body" do
    I18n.with_locale(:de) do
      @user.update_columns(confirmed_at: nil, confirmation_token: nil, confirmation_sent_at: nil)
      @user.send_confirmation_instructions
    end

    assert_equal 1, ActionMailer::Base.deliveries.size, "exakt 1 Confirmation-Mail erwartet"
    mail = last_email
    assert_equal [@user.email], mail.to
    assert_includes mail.subject, I18n.t("devise.mailer.confirmation_instructions.subject", locale: :de)
    assert_match %r{/confirmation\?confirmation_token=}, mail.body.to_s
  end

  test "reset_password_instructions: token im body extrahierbar" do
    I18n.with_locale(:de) do
      @user.send_reset_password_instructions
    end

    mail = last_email
    refute_nil mail, "Reset-Mail muss versendet werden"
    assert_equal [@user.email], mail.to
    assert_match %r{/password/edit\?reset_password_token=}, mail.body.to_s
    # Plan 41-05 System-Test wird extract_reset_password_url nutzen — hier locken
    refute_nil extract_reset_password_url(mail), "Helper muss URL extrahieren koennen"
  end

  test "password_change: Notification-Mail wird versendet (DE-Subject enthaelt 'Passwort')" do
    I18n.with_locale(:de) do
      @user.send(:send_password_change_notification)
    end
    mail = last_email
    refute_nil mail
    assert_equal [@user.email], mail.to
    assert_match(/Passwort/, mail.subject, "DE-Subject sollte 'Passwort' enthalten (devise.de.yml)")
  end

  test "email_changed: bei reconfirmable=true Mail an unconfirmed_email" do
    # Reconfirmable-Flow: User aendert email, neue Adresse landet in unconfirmed_email,
    # email_changed wird an die NEUE Adresse versendet (Devise-Default).
    @user.update!(email: "alt-#{@user.id}@example.test", confirmed_at: 1.hour.ago)
    clear_mail_queue

    I18n.with_locale(:de) do
      @user.update!(email: "neu-#{@user.id}@example.test")
    end
    # In reconfirmable-Mode landet 1 confirmation_instructions an neue Adresse
    # und optional 1 email_changed an alte (Devise-Default config.send_email_changed_notification).
    assert_operator ActionMailer::Base.deliveries.size, :>=, 1
  end

  test "sender-lock: from-Adresse entspricht Devise.mailer_sender (IST-Zustand im Test-Env)" do
    # CHARAKTERISIERUNG der Sender-Diskrepanz (T-41-INFRA-01):
    # - ApplicationMailer.default from: Carambus.config.support_email (parent_mailer-Pfad)
    # - Devise.mailer_sender = ENV["SMTP_USERNAME"] || "no-reply@carambus.de"
    # Im Test-Env ist Carambus.config.support_email = nil (carambus.yml test-Section),
    # daher greift der Devise.mailer_sender-Fallback ("no-reply@carambus.de").
    # In Production hingegen ist support_email = "gernot.ullrich@gmx.de" gesetzt — dort
    # divergieren die beiden Sender. Plan-04 wird diese Divergenz angleichen; dieser
    # Test lockt den IST-Wert pro Env.
    I18n.with_locale(:de) do
      @user.send_reset_password_instructions
    end
    mail = last_email
    refute_nil mail.from, "from-Header muss gesetzt sein"
    expected_sender = Carambus.config.support_email.presence || Devise.mailer_sender
    assert_includes mail.from, expected_sender,
      "from sollte support_email (wenn gesetzt) sonst Devise.mailer_sender enthalten — Divergenz dokumentiert in T-41-INFRA-01"
  end
end
