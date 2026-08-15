# frozen_string_literal: true

require "test_helper"

# Deckt Rollenerkennung und Kontext-Aufloesung ab — die beiden Punkte, an denen eine Instanz
# stillschweigend die falsche Rolle bzw. eine fremde Region annimmt.
#
# Netzwerk-Proben sind hier durchgaengig aus (`probe_network: false`); sie sind Integrations-,
# nicht Unit-Verhalten.
class Diagnostics::ChainCheckTest < ActiveSupport::TestCase
  test "leere carambus_api_url bedeutet Authority" do
    with_config(carambus_api_url: "", location_id: nil, context: "API") do
      assert_equal :authority, Diagnostics::ChainCheck.new(probe_network: false).role
    end
  end

  test "gesetzte api_url ohne location_id bedeutet Region Server" do
    with_config(carambus_api_url: "https://api.carambus.de", location_id: nil, context: "BBV") do
      assert_equal :region_server, Diagnostics::ChainCheck.new(probe_network: false).role
    end
  end

  test "gesetzte api_url mit location_id bedeutet Location Server" do
    with_config(carambus_api_url: "https://api.carambus.de", location_id: 2426, context: "BBV") do
      assert_equal :location_server, Diagnostics::ChainCheck.new(probe_network: false).role
    end
  end

  # location_id: 0 ist der Wert der Vorlage-Config und bedeutet "kein Spielort" — nicht Location 0.
  test "location_id 0 zaehlt nicht als Spielort" do
    with_config(carambus_api_url: "https://api.carambus.de", location_id: 0, context: "BBV") do
      assert_equal :region_server, Diagnostics::ChainCheck.new(probe_network: false).role
    end
  end

  test "kleingeschriebener Kontext wird aufgeloest" do
    with_config(carambus_api_url: "https://api.carambus.de", location_id: nil, context: "bbv") do
      check = run_checks.find { |c| c.name == "Server-Kontext" }
      assert check.ok?, check.detail
      assert_match(/Region BBV/, check.detail)
    end
  end

  test "unbekannter Kontext ist ein Blocker mit Hinweis" do
    with_config(carambus_api_url: "https://api.carambus.de", location_id: nil, context: "GIBTESNICHT") do
      check = run_checks.find { |c| c.name == "Server-Kontext" }
      assert check.failed?
      assert_match(/still auf den Default/, check.hint)
    end
  end

  test "Authority ohne Kontext ist in Ordnung" do
    with_config(carambus_api_url: "", location_id: nil, context: "") do
      check = run_checks.find { |c| c.name == "Server-Kontext" }
      assert check.ok?
    end
  end

  private

  def run_checks = Diagnostics::ChainCheck.new(probe_network: false).call

  # Ganze Config ersetzen (Muster aus prepare_tournament_test.rb): einzelne Keys fehlen in der
  # Testumgebung, ein stub darauf schlaegt fehl.
  def with_config(attrs, &block)
    Carambus.stub(:config, OpenStruct.new(attrs), &block)
  end
end
