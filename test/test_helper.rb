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

# Load test support files
Dir[Rails.root.join('test', 'support', '**', '*.rb')].each { |f| require f }

# Disable LocalProtector for all test records
module LocalProtectorTestOverride
  def disallow_saving_global_records
    # Skip protection in test environment
    true
  end
end

LocalProtector.prepend(LocalProtectorTestOverride)

# Disable ApiProtector for all test records.
# ApiProtector uses ActiveSupport::Concern with `included do` which defines
# disallow_saving_local_records directly on each including class. Prepending
# to the module itself doesn't override already-installed methods. We must
# prepend the override directly to each class that includes ApiProtector.
module ApiProtectorTestOverride
  def disallow_saving_local_records
    # Skip protection in test environment
    true
  end
end

# Load model files so their classes are defined before we patch them
Dir[Rails.root.join("app/models/**/*.rb")].each { |f| require f rescue nil }

ObjectSpace.each_object(Class).select { |klass|
  klass.ancestors.include?(ApiProtector) rescue false
}.each do |klass|
  klass.prepend(ApiProtectorTestOverride) unless klass.ancestors.include?(ApiProtectorTestOverride)
end

# Uncomment to view full stack trace in tests
# Rails.backtrace_cleaner.remove_silencers!

if defined?(Sidekiq)
  require "sidekiq/testing"
  Sidekiq::Testing.fake!
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

    # Scenario-Snapshot beim Laden des test_helpers einfrieren — einzelne Tests
    # (tournament_scraping_test.rb, tournaments_controller_test.rb u. a.)
    # mutieren Carambus.config.carambus_api_url zur Laufzeit. Dadurch würde ein
    # spät evaluiertes present? das falsche Scenario liefern und Gates ins
    # Leere laufen lassen. Der Snapshot entspricht dem Zustand bei Boot —
    # genau der Wert, der auch has_paper_trail / local_server? in
    # LocalProtector einmalig zur Class-Load-Zeit bestimmt hat.
    LOCAL_SERVER_SCENARIO = Carambus.config.carambus_api_url.present?

    # Scenario-Gate: Tests, die nur auf dem API-Server sinnvoll sind
    # (z. B. PaperTrail-Verhalten, das per LocalProtector nur aktiviert wird,
    # wenn `carambus_api_url` NICHT gesetzt ist).
    def skip_unless_api_server
      skip "Nur auf API-Server (carambus_api_url leer)" if LOCAL_SERVER_SCENARIO
    end

    # Scenario-Gate: Tests, die nur auf einem Local Server sinnvoll sind
    # (z. B. Verhalten von ApiProtector, Sync-Logik gegen API-Server).
    def skip_unless_local_server
      skip "Nur auf Local Server (carambus_api_url gesetzt)" unless LOCAL_SERVER_SCENARIO
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
    # D-41-A BLOCKER-3 Fix: MailHelpers in IntegrationTest fuer Controller-/Request-Tests
    include MailHelpers
  end
end

# D-41-A BLOCKER-3 Fix: MailHelpers in ActionMailer::TestCase fuer Mailer-Tests in test/mailers/
require "rails/test_help"
class ActionMailer::TestCase
  include MailHelpers
end

# D-41-A BLOCKER-3 Fix: ApplicationSystemTestCase erbt nicht von IntegrationTest
# (sondern von ActionDispatch::SystemTestCase) — daher hier explizit included.
# Plan-05 setup kann ohne extend-Workaround arbeiten. Guarded via defined?, falls
# test_helper.rb geladen wird bevor application_system_test_case.rb da ist.
require_relative "application_system_test_case" if File.exist?(File.expand_path("application_system_test_case.rb", __dir__))
if defined?(ApplicationSystemTestCase)
  class ApplicationSystemTestCase
    include MailHelpers
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
