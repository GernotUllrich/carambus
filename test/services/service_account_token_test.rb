# frozen_string_literal: true

require "test_helper"

# Plan 29-05: Die JWT-Beschaffung, die sich Location Server (Abschluss melden) und Authority
# (Meldeliste holen) teilen. Aus `ResultReporter#token_for` extrahiert — die Tests halten das
# Verhalten fest, das beide Aufrufer erwarten.
class ServiceAccountTokenTest < ActiveSupport::TestCase
  BASE = "https://nbv.carambus.de"

  def fetch
    ServiceAccountToken.fetch(base_url: BASE, username: "bridge@carambus.de", password: "geheim")
  end

  test "meldet sich an und gibt den reinen Bearer-Wert zurueck" do
    stub = stub_request(:post, "#{BASE}/login")
      .with do |request|
        body = JSON.parse(request.body)
        assert_equal "bridge@carambus.de", body.dig("user", "email")
        assert_equal "geheim", body.dig("user", "password")
        true
      end
      .to_return(status: 200, headers: {"Authorization" => "Bearer test-jwt"}, body: "{}")

    assert_equal "test-jwt", fetch, "das Bearer-Praefix gehoert nicht in den Rueckgabewert"
    assert_requested stub
  end

  test "abgelehnte Anmeldung nennt Status und Ziel" do
    stub_request(:post, "#{BASE}/login").to_return(status: 401, body: "")

    error = assert_raises(RuntimeError) { fetch }

    assert_match(/Anmeldung am Region Server fehlgeschlagen \(HTTP 401\)/, error.message)
    assert_includes error.message, "#{BASE}/login"
  end

  # Ein 200 ohne Authorization-Header ist der stille Fehlerfall: ohne diese Pruefung liefe der
  # Aufrufer mit einem leeren Token weiter und schluege erst am Zielendpunkt fehl.
  test "fehlender Authorization-Header bricht ab" do
    stub_request(:post, "#{BASE}/login").to_return(status: 200, body: "{}")

    error = assert_raises(RuntimeError) { fetch }

    assert_match(/kein Authorization-Header/, error.message)
  end
end
