# frozen_string_literal: true

require "securerandom"

# Konten, die ein aus dem Regionsdump befuellter Server selbst anlegt (Plan 18-03).
#
# Der Dump enthaelt keine Benutzer, und User synct nicht (kein PaperTrail). Auf bestehenden Servern kam das
# Scoreboard-Konto als globaler Benutzer mit der Authority-Kopie; hier entsteht es lokal (id >= MIN_ID nach
# Version.sequence_reset). Der erste Admin wird bewusst per Befehl mit E-Mail angelegt, nicht automatisch.
#
# confirmed_at wird direkt gesetzt: User#skip_confirmation! ist leer ueberschrieben, und ohne Bestaetigung
# liesse Devise (:confirmable, allow_unconfirmed_access_for 0) keine Anmeldung zu. Mit gesetztem confirmed_at
# verschickt Devise auch keine Bestaetigungsmail.
module LocalAccounts
  SCOREBOARD_EMAIL = "scoreboard@carambus.de"

  module_function

  # Liefert [user, angelegt?]. Ein vorhandenes Konto bleibt unveraendert. Das Passwort wird nie gebraucht:
  # das Scoreboard meldet sich per bypass_sign_in an (LocationsController#scoreboard).
  def ensure_scoreboard!
    user = User.find_by(email: SCOREBOARD_EMAIL)
    return [user, false] if user

    password = SecureRandom.alphanumeric(32)
    user = User.create!(email: SCOREBOARD_EMAIL, password: password, password_confirmation: password,
      role: :player, confirmed_at: Time.current)
    [user, true]
  end

  # Liefert [user, passwort]. Bricht mit ArgumentError ab, wenn die E-Mail schon vergeben oder ungueltig ist.
  def create_admin!(email)
    email = email.to_s.strip.downcase
    raise ArgumentError, "Benutzer #{email} gibt es schon — nichts geändert" if User.exists?(email: email)

    password = SecureRandom.alphanumeric(20)
    user = User.new(email: email, password: password, password_confirmation: password, role: :system_admin,
      confirmed_at: Time.current)
    raise ArgumentError, "Konto nicht angelegt: #{user.errors.full_messages.join(", ")}" unless user.save

    [user, password]
  end
end
