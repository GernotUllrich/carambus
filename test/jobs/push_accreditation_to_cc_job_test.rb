# frozen_string_literal: true

require "test_helper"

# Plan 44-01: Tests für den asynchronen CC-Push-Job + den Reflex-Seam enqueue_for.
# AC-1 (Enqueue/Skip) + AC-3 (Discard) + Target-Symbolisierung in perform.
class PushAccreditationToCcJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @orig_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    @tournament = tournaments(:local)
    @player = players(:jaspers)
    @user = users(:system_admin)
  end

  teardown do
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = @orig_adapter
  end

  test "enqueue_for enqueued den Job, wenn das Turnier CC-verknüpft ist" do
    @tournament.stub(:tournament_cc, Object.new) do
      assert_enqueued_with(job: PushAccreditationToCcJob) do
        PushAccreditationToCcJob.enqueue_for(
          tournament: @tournament, player: @player, target: :deaccredit, acting_user: @user
        )
      end
    end
  end

  test "enqueue_for enqueued NICHT ohne tournament_cc (kein CC-Bezug)" do
    @tournament.stub(:tournament_cc, nil) do
      assert_no_enqueued_jobs do
        PushAccreditationToCcJob.enqueue_for(
          tournament: @tournament, player: @player, target: :accredit, acting_user: @user
        )
      end
    end
  end

  test "perform delegiert an AccreditationPush mit symbolisiertem target + geladenen Records" do
    captured = nil
    stub_call = lambda do |*args, **kwargs|
      captured = kwargs.empty? ? args.first : kwargs
      {status: :noop}
    end
    Tournament::CcSync::AccreditationPush.stub(:call, stub_call) do
      assert_nothing_raised do
        PushAccreditationToCcJob.perform_now(
          tournament_id: @tournament.id, player_id: @player.id,
          acting_user_id: @user.id, target: "deaccredit"
        )
      end
    end
    assert_equal :deaccredit, captured[:target]
    assert_equal @tournament.id, captured[:tournament].id
    assert_equal @player.id, captured[:player].id
  end

  test "perform verwirft (discard) bei fehlendem Turnier (RecordNotFound)" do
    assert_nothing_raised do
      PushAccreditationToCcJob.perform_now(
        tournament_id: -1, player_id: @player.id, acting_user_id: @user.id, target: "accredit"
      )
    end
  end
end
