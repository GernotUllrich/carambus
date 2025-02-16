class NotifierMailer < ApplicationMailer
  def result(tournament, recipient, subject, filename, filepath)
    attachments[filename] = File.read(filepath)
    @tournament = tournament
    mail(to: recipient, subject: subject)
  end
end
