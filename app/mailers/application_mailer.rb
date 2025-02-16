class ApplicationMailer < ActionMailer::Base
  default from: Carambus.config.support_email
  layout "mailer"

  # Include any view helpers from your main app to use in mailers here
  helper ApplicationHelper
end
