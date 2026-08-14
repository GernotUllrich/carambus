# frozen_string_literal: true

require "test_helper"

module ApplicationCable
  # Regression zu c1e473cb (2025-02-25): find_verified_user gab dort "User.first"
  # zurueck und hat damit JEDE WebSocket-Verbindung als ersten User der Tabelle
  # authentifiziert — unabhaengig von Session und Login.
  class ConnectionTest < ActionCable::Connection::TestCase
    tests ApplicationCable::Connection

    # Minimaler Warden-Ersatz: ActionCable::Connection::TestCase baut kein
    # Rack-Env mit Devise-Middleware auf, daher wird env["warden"] gestellt.
    FakeWarden = Struct.new(:user)

    test "weist verbindung ohne warden ab" do
      assert_reject_connection { connect }
    end

    test "weist verbindung ohne angemeldeten user ab" do
      assert_reject_connection { connect env: { "warden" => FakeWarden.new(nil) } }
    end

    test "uebernimmt den angemeldeten user aus der session" do
      user = users(:one)
      connect env: { "warden" => FakeWarden.new(user) }

      assert_equal user.id, connection.current_user.id
    end

    test "authentifiziert nicht pauschal als erster user" do
      # Kernaussage der Regression: ein anderer angemeldeter User darf NICHT
      # auf User.first zurueckfallen.
      other = users(:admin)
      connect env: { "warden" => FakeWarden.new(other) }

      assert_equal other.id, connection.current_user.id
    end
  end
end
