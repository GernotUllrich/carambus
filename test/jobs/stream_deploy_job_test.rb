# frozen_string_literal: true

require "test_helper"

class StreamDeployJobTest < ActiveJob::TestCase
  test "delegates to StreamControlJob with the deploy action" do
    called_with = nil
    StreamControlJob.stub(:perform_now, ->(id, action) { called_with = [id, action] }) do
      StreamDeployJob.perform_now(123)
    end
    assert_equal [123, "deploy"], called_with
  end
end
