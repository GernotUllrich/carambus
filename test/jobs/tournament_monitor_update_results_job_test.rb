# frozen_string_literal: true

require "test_helper"

class TournamentMonitorUpdateResultsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @original_api_url = Carambus.config.carambus_api_url
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  test "skips on API server (default test env — no carambus_api_url)" do
    # Default test env has blank carambus_api_url, so ApplicationRecord.local_server? == false
    # The job should return early without raising
    Carambus.config.carambus_api_url = nil
    assert_nothing_raised do
      TournamentMonitorUpdateResultsJob.perform_now(nil)
    end
  end

  test "skips when local_server? is false regardless of argument" do
    ApplicationRecord.stub(:local_server?, false) do
      assert_nothing_raised do
        TournamentMonitorUpdateResultsJob.perform_now(nil)
      end
    end
  end
end
