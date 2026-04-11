# frozen_string_literal: true

require "test_helper"

class TournamentMonitorChannelTest < ActionCable::Channel::TestCase
  test "rejects subscription on API server" do
    ApplicationRecord.stub(:local_server?, false) do
      subscribe
      assert subscription.rejected?
    end
  end

  test "confirms subscription on local server" do
    ApplicationRecord.stub(:local_server?, true) do
      subscribe
      assert subscription.confirmed?
      assert_has_stream "tournament-monitor-stream"
    end
  end
end
