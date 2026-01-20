# test/test_helper.rb
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "webmock/minitest"
require 'factory_bot_rails'

# Disable LocalProtector for all test records
module LocalProtectorTestOverride
  def disallow_saving_global_records
    # Skip protection in test environment
    true
  end
end

LocalProtector.prepend(LocalProtectorTestOverride)

# Uncomment to view full stack trace in tests
# Rails.backtrace_cleaner.remove_silencers!

if defined?(Sidekiq)
  require "sidekiq/testing"
  Sidekiq.logger.level = Logger::WARN
end

if defined?(SolidQueue)
  SolidQueue.logger.level = Logger::WARN
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def json_response
      JSON.decode(response.body)
    end

    include FactoryBot::Syntax::Methods
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end

WebMock.disable_net_connect!({
  allow_localhost: true,
  allow: [
    "chromedriver.storage.googleapis.com",
    "api.stripe.com",
    "rails-app",
    "selenium"
  ]
})
