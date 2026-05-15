# frozen_string_literal: true

require "test_helper"

# Plan 41-04 Task 2 (D-41-B Retry+Bounce-Handling): Job-Verhalten unter SMTP-Error-Szenarien.
class DeviseMailJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @user = users(:valid)
  end

  test "User#send_devise_notification enqueued DeviseMailJob (kein synchrones deliver_now)" do
    assert_enqueued_with(job: DeviseMailJob) do
      @user.send_reset_password_instructions
    end
    # Im Test-Env mit ActiveJob :test-Adapter: deliveries.size bleibt 0 bis perform_enqueued_jobs.
    assert_equal 0, ActionMailer::Base.deliveries.size,
      "Mail darf erst beim Job-Perform versendet werden (deliver_later-Pfad)"
  end

  test "perform_enqueued_jobs liefert Mail im Erfolgs-Fall aus" do
    perform_enqueued_jobs do
      @user.send_reset_password_instructions
    end
    assert_equal 1, ActionMailer::Base.deliveries.size,
      "Nach perform_enqueued_jobs muss Mail versendet sein"
  end

  test "retry_on Net::SMTPAuthenticationError: bis zu 3 Attempts" do
    # Stub: erste 2 Aufrufe schmeissen SMTPAuthenticationError, 3. ist erfolgreich.
    # Wir stubben Devise::Mailer.reset_password_instructions, weil DeviseMailJob#perform
    # die Mailer-Klasse via .constantize.send(notification, ...) aufruft.
    call_count = 0
    original = Devise::Mailer.method(:reset_password_instructions)
    Devise::Mailer.define_singleton_method(:reset_password_instructions) do |*_args|
      call_count += 1
      if call_count < 3
        raise Net::SMTPAuthenticationError, "transient auth-fail (simuliert)"
      else
        # Erfolgreich: returne Message-Mock mit deliver_now-Method
        OpenStruct.new(deliver_now: true)
      end
    end

    begin
      # ActiveJob retry mit :test-Adapter — perform_enqueued_jobs respektiert retry_on
      perform_enqueued_jobs do
        @user.send_reset_password_instructions
      end
    ensure
      Devise::Mailer.define_singleton_method(:reset_password_instructions, original)
    end

    assert_equal 3, call_count, "Job muss bis zu 3 Mal versuchen (1 + 2 retries)"
  end

  test "discard_on Net::SMTPFatalError: permanenter Fehler verwirft Job (kein Crash)" do
    call_count = 0
    original = Devise::Mailer.method(:reset_password_instructions)
    Devise::Mailer.define_singleton_method(:reset_password_instructions) do |*_args|
      call_count += 1
      raise Net::SMTPFatalError, "permanent bounce (simuliert)"
    end

    begin
      # KEIN raise — discard_on faengt; Job wird in Log verworfen
      assert_nothing_raised do
        perform_enqueued_jobs do
          @user.send_reset_password_instructions
        end
      end
    ensure
      Devise::Mailer.define_singleton_method(:reset_password_instructions, original)
    end

    assert_equal 1, call_count, "Permanenter Fehler darf NUR 1 Mal versucht werden (discard_on)"
  end
end
