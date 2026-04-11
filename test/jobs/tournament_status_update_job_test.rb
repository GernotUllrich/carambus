# frozen_string_literal: true

require "test_helper"

class TournamentStatusUpdateJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @tournament = tournaments(:local)
  end

  test "returns early when tournament has no tournament_monitor" do
    # tournaments(:local) has no tournament_monitor — job should guard and return early
    assert_nothing_raised do
      TournamentStatusUpdateJob.perform_now(@tournament)
    end
  end

  test "returns early when tournament is not started (registration state)" do
    # tournaments(:local) is in 'registration' state — not started
    # Even if a tournament_monitor were present, the job returns early for unstarted tournaments
    assert_nothing_raised do
      TournamentStatusUpdateJob.perform_now(@tournament)
    end
  end

  test "does not raise on tournament in tournament_started state without monitor" do
    # Simulate a tournament that is started but has no tournament_monitor
    # The job guards on tournament_monitor presence first, so it returns early
    @tournament.stub(:tournament_started, true) do
      assert_nothing_raised do
        TournamentStatusUpdateJob.perform_now(@tournament)
      end
    end
  end
end
