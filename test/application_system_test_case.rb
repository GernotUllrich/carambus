require "test_helper"
require "capybara/rails"

Dir["#{File.dirname(__FILE__)}/support/system/**/*.rb"].sort.each { |f| require f }

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include Devise::Test::IntegrationHelpers
  # Backport
  def self.served_by(host:, port:)
    Capybara.server_host = host
    Capybara.server_port = port
  end

  if ENV["CAPYBARA_SERVER_PORT"]
    served_by host: "rails-app", port: ENV["CAPYBARA_SERVER_PORT"]

    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400], options: {
      browser: :remote,
      url: "http://#{ENV["SELENIUM_HOST"]}:4444"
    }
  else
    driven_by :selenium, using: ENV.fetch("DRIVER", :headless_chrome).to_sym, screen_size: [1400, 1400]
  end

  include Warden::Test::Helpers
  include TrixSystemTestHelper

  setup do
    # Enable local_server? for system tests so TableMonitorChannel accepts
    # subscriptions and TableMonitorJob executes broadcasts (per D-03)
    @original_carambus_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://test-api"
  end

  teardown do
    Carambus.config.carambus_api_url = @original_carambus_api_url
  end

  private

  # Multi-session helper for Phase 18 two-session isolation tests.
  # Usage: in_session(:scoreboard_a) { visit_scoreboard(@tm_a) }
  def in_session(name, &block)
    Capybara.using_session(name, &block)
  end

  # Visit the scoreboard page for a given TableMonitor.
  def visit_scoreboard(table_monitor, locale: :de)
    visit table_monitor_url(table_monitor, locale: locale)
  end

  # Wait for the TableMonitorChannel WebSocket subscription to be confirmed
  # by the server (i.e., the connected() callback has fired in the browser).
  # The JS sets data-cable-connected="true" on <html> in the connected() callback.
  # Uses Capybara's assert_selector retry loop (no sleep — Capybara polls the DOM).
  # Call this after visiting a scoreboard page, before triggering broadcasts,
  # to avoid the race where the broadcast is sent before the subscription is
  # established server-side.
  def wait_for_actioncable_connection(timeout: 5)
    assert_selector "html[data-cable-connected='true']", wait: timeout
  end
end

Capybara.default_max_wait_time = 10
Capybara.default_driver = :selenium_chrome_headless
Capybara.default_normalize_ws = true

# Add a route for easily switching accounts in system tests
Rails.application.routes.append do
  get "/accounts/:id/switch", to: "accounts#switch", as: :test_switch_account
end
Rails.application.reload_routes!
