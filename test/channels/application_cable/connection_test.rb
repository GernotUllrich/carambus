# frozen_string_literal: true

require "test_helper"

module ApplicationCable
  # Regression zu c1e473cb (2025-02-25): find_verified_user gab dort "User.first"
  # zurueck und hat damit JEDE WebSocket-Verbindung als ersten User der Tabelle
  # authentifiziert — unabhaengig von Session und Login.
  #
  # Anonyme Verbindungen sind erlaubt (current_user = nil), aber sie duerfen NIE
  # eine fremde Identitaet erhalten. Genau das trennen diese Tests.
  class ConnectionTest < ActionCable::Connection::TestCase
    tests ApplicationCable::Connection

    # Minimaler Warden-Ersatz: ActionCable::Connection::TestCase baut kein
    # Rack-Env mit Devise-Middleware auf, daher wird env["warden"] gestellt.
    FakeWarden = Struct.new(:user)

    test "uebernimmt den angemeldeten user aus der session" do
      user = users(:one)
      connect env: {"warden" => FakeWarden.new(user)}

      assert_equal user.id, connection.current_user.id
    end

    test "uebernimmt einen anderen angemeldeten user unveraendert" do
      other = users(:admin)
      connect env: {"warden" => FakeWarden.new(other)}

      assert_equal other.id, connection.current_user.id
    end

    # Kern der Regression: anonym heisst nil — nicht "irgendein User".
    test "verbindung ohne warden ist anonym statt fremder identitaet" do
      connect

      assert_nil connection.current_user
    end

    test "verbindung ohne angemeldeten user ist anonym statt fremder identitaet" do
      connect env: {"warden" => FakeWarden.new(nil)}

      assert_nil connection.current_user
    end

    # Explizit gegen den alten Hack: selbst wenn User.first existiert, darf eine
    # anonyme Verbindung ihn nicht bekommen.
    test "faellt anonym nicht auf User.first zurueck" do
      refute_nil User.first, "Fixture-Vorbedingung: es muss mindestens einen User geben"

      connect

      assert_nil connection.current_user
    end

    # Anonyme Verbindungen muessen zustandekommen — oeffentliche Seiten nutzen
    # Reflexes (Live-Suche) und brauchen dafuer eine Cable-Verbindung.
    test "anonyme verbindung wird nicht abgewiesen" do
      assert_nothing_raised { connect }
    end

    # Fallback: Warden ist beim WebSocket-Handshake nicht immer befuellt (auf
    # api.carambus.de war es das fuer eingeloggte Nutzer nie). Dann muss die Devise-
    # Session direkt ausgewertet werden.
    test "erkennt den user ueber die session wenn warden fehlt" do
      user = users(:one)
      connect session: {"warden.user.user.key" => [[user.id], "salt"]}

      assert_equal user.id, connection.current_user.id
    end

    test "warden hat vorrang vor der session" do
      warden_user = users(:one)
      session_user = users(:admin)
      connect env: {"warden" => FakeWarden.new(warden_user)},
        session: {"warden.user.user.key" => [[session_user.id], "salt"]}

      assert_equal warden_user.id, connection.current_user.id
    end

    test "unbekannte user-id in der session ergibt anonym" do
      connect session: {"warden.user.user.key" => [[999_999_999], "salt"]}

      assert_nil connection.current_user
    end
  end
end
