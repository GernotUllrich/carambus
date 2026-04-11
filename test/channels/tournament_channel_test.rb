# frozen_string_literal: true

require "test_helper"

class TournamentChannelTest < ActionCable::Channel::TestCase
  test "subscribes with tournament_id and streams from specific stream" do
    subscribe(tournament_id: 42)
    assert subscription.confirmed?
    assert_has_stream "tournament-stream-42"
  end

  test "subscribes without tournament_id and streams from generic stream" do
    subscribe
    assert subscription.confirmed?
    assert_has_stream "tournament-stream"
  end
end
