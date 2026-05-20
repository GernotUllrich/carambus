# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  # Plan 41-04 Task 1 (D-41-B): Sender ueber alle Mails identisch zu Devise.mailer_sender.
  # Vorher: Carambus.config.support_email — divergierte zu config.mailer_sender (ENV["SMTP_USERNAME"])
  # in Production und fuehrte zu SPF/DKIM-Mismatch + Gmail-Spam-Klassifizierung.
  # Proc statt Lambda: ActionMailer ruft die Default-Proc mit dem Mailer-Instance-Arg auf;
  # Lambda mit strikter Arity-Pruefung wuerde ArgumentError werfen. Proc verwirft das Arg.
  default from: proc { Devise.mailer_sender }
  layout "mailer"

  # Include any view helpers from your main app to use in mailers here
  helper ApplicationHelper
end
