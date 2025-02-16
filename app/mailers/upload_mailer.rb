class UploadMailer < ApplicationMailer
  def report_upload(recipient, user, filename)
    @user = user
    @filename = filename
    mail(to: recipient, subject: "User[#{@user.id}] - #{@user.name} - uploaded #{@filename}")
  end
end
