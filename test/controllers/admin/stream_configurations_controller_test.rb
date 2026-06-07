# frozen_string_literal: true

require "test_helper"

module Admin
  class StreamConfigurationsControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      # Test-Umgebung nutzt standardmäßig den :inline-Adapter; für
      # assert_enqueued_with brauchen wir den :test-Adapter.
      @original_queue_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      @config = StreamConfiguration.create!(table: tables(:one))
    end

    teardown do
      ActiveJob::Base.queue_adapter = @original_queue_adapter
    end

    test "deploy_all enqueues a StreamDeployJob per configuration and redirects" do
      assert_enqueued_with(job: StreamDeployJob, args: [@config.id]) do
        post deploy_all_admin_stream_configurations_path
      end
      assert_redirected_to admin_stream_configurations_path
    end

    test "deploy_all scopes to a location when location_id is given" do
      assert_enqueued_with(job: StreamDeployJob, args: [@config.id]) do
        post deploy_all_admin_stream_configurations_path, params: { location_id: @config.location.id }
      end
    end
  end
end
