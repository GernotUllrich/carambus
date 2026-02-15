# test/test_helper.rb
ENV["RAILS_ENV"] ||= "test"

# SimpleCov must be loaded before application code
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails' do
    # Focus on app code, not test code
    add_filter '/test/'
    add_filter '/config/'
    add_filter '/vendor/'
    
    # Group by type for better reporting
    add_group 'Models', 'app/models'
    add_group 'Controllers', 'app/controllers'
    add_group 'Services', 'app/services'
    add_group 'Concerns', 'app/models/concerns'
    add_group 'Helpers', 'app/helpers'
    
    # Track coverage for critical files
    track_files '{app}/**/*.rb'
    
    # Set minimum coverage (not enforced, just reported)
    minimum_coverage 60
  end
end

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
    # Disabled for now to avoid database issues with fixtures
    # parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def json_response
      JSON.decode(response.body)
    end

    include FactoryBot::Syntax::Methods
    
    # Load custom test helpers
    Dir[Rails.root.join('test', 'support', '**', '*.rb')].sort.each { |f| require f }
    include ScrapingHelpers
    include SnapshotHelpers
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
