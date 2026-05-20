# frozen_string_literal: true

# D-41-A Wave-0 Skeleton (VALIDATION.md Pflichtlieferung).
#
# Aktueller Stand: Plan-05 System-Tests nutzen ActionMailer::Base.deliveries direkt
# via MailHelpers (siehe test/support/mail_helpers.rb), KEIN letter_opener-Parsing.
# Dieser Module ist Reserve: falls spaetere E2E-Tests in Dev (nicht test-env)
# gegen die echte letter_opener-Mailbox laufen sollen, hier die Parsing-Logik
# ergaenzen (tmp/letter_opener/*.html lesen + Token extrahieren).
module LetterOpenerHelper
  # Placeholder: tmp/letter_opener-Ordner durchsuchen und letzte Mail liefern.
  # Wird befuellt sobald Bedarf entsteht — bis dahin nutzen Tests MailHelpers.
  def letter_opener_last_mail_path
    Dir.glob(Rails.root.join("tmp/letter_opener/**/*.html")).max_by { |f| File.mtime(f) }
  end
end
