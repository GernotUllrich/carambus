# frozen_string_literal: true

require "test_helper"

# Plan 44-03: Tests für den Finalize-Push-Job + Controller-Seam enqueue_for.
class FinalizeTeilnehmerlisteJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  TcDouble = Struct.new(:meldeliste_cc_id)

  setup do
    @orig_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    @tournament = tournaments(:local)
    @user = users(:system_admin)
  end

  teardown do
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = @orig_adapter
  end

  test "enqueue_for enqueued bei CC-Verknüpfung mit meldeliste_cc_id" do
    @tournament.stub(:tournament_cc, TcDouble.new(1347)) do
      assert_enqueued_with(job: FinalizeTeilnehmerlisteJob) do
        FinalizeTeilnehmerlisteJob.enqueue_for(tournament: @tournament, acting_user: @user)
      end
    end
  end

  test "enqueue_for enqueued NICHT ohne meldeliste_cc_id" do
    @tournament.stub(:tournament_cc, TcDouble.new(nil)) do
      assert_no_enqueued_jobs do
        FinalizeTeilnehmerlisteJob.enqueue_for(tournament: @tournament, acting_user: @user)
      end
    end
  end

  test "enqueue_for enqueued NICHT ohne tournament_cc" do
    @tournament.stub(:tournament_cc, nil) do
      assert_no_enqueued_jobs do
        FinalizeTeilnehmerlisteJob.enqueue_for(tournament: @tournament, acting_user: @user)
      end
    end
  end

  test "perform delegiert an FinalizePush mit geladenen Records" do
    captured = nil
    stub_call = lambda do |*args, **kwargs|
      captured = kwargs.empty? ? args.first : kwargs
      {status: :finalized}
    end
    Tournament::CcSync::FinalizePush.stub(:call, stub_call) do
      assert_nothing_raised do
        FinalizeTeilnehmerlisteJob.perform_now(tournament_id: @tournament.id, acting_user_id: @user.id)
      end
    end
    assert_equal @tournament.id, captured[:tournament].id
    assert_equal @user.id, captured[:acting_user].id
  end

  test "perform verwirft (discard) bei fehlendem Turnier (RecordNotFound)" do
    assert_nothing_raised do
      FinalizeTeilnehmerlisteJob.perform_now(tournament_id: -1, acting_user_id: @user.id)
    end
  end
end
