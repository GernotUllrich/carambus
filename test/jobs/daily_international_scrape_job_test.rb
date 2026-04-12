# frozen_string_literal: true

require "test_helper"

# Tests for DailyInternationalScrapeJob video matching wiring (Plan 27-03).
#
# Verifies Step 3b (Video::TournamentMatcher) and Step 3c (Kozoom cross-ref)
# are called by the job, that errors are rescued gracefully, that the return
# hash includes :matched, and that unassigned video count decreases when
# matching fixture data is present.
#
# External HTTP is blocked by WebMock (configured in test_helper).
# ScrapeYoutubeJob, SoopliveScraper, KozoomScraper, and
# SoopliveBilliardsClient#fetch_games are stubbed so the test focuses
# only on the video matching steps.
class DailyInternationalScrapeJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Stub out all external-facing scraping steps so only the matching
  # steps (3b and 3c) run against real fixture data.
  def stub_scraping_steps(&block)
    fake_youtube = Minitest::Mock.new
    fake_youtube.expect(:call, 0, [], days_back: Integer)

    fake_soop_scraper = Minitest::Mock.new

    # SoopliveBilliardsClient#fetch_games is stubbed to return []
    # (no network call needed; Step 1b logs the count)
    fake_billiards_client = Minitest::Mock.new
    fake_billiards_client.expect(:fetch_games, [])

    # KozoomScraper stubbed — credentials will be blank in test env
    # so the branch is skipped automatically; no mock needed.

    ScrapeYoutubeJob.stub(:perform_now, 0) do
      SoopliveScraper.stub(:new, fake_soop_scraper) do
        SoopliveBilliardsClient.stub(:new, fake_billiards_client) do
          block.call
        end
      end
    end
  end

  # ------------------------------------------------------------------
  # Test 1: Step 3b calls Video::TournamentMatcher.call
  # ------------------------------------------------------------------
  test "perform calls Video::TournamentMatcher.call in Step 3b" do
    matcher_called = false

    stub_scraping_steps do
      Video::TournamentMatcher.stub(:call, ->(**_kwargs) {
        matcher_called = true
        { assigned_count: 0, skipped_count: 0, results: [] }
      }) do
        SoopliveBilliardsClient.stub(:cross_reference_kozoom_videos, { assigned_count: 0 }) do
          DailyInternationalScrapeJob.new.perform
        end
      end
    end

    assert matcher_called, "Expected Video::TournamentMatcher.call to be called in Step 3b"
  end

  # ------------------------------------------------------------------
  # Test 2: Step 3c calls SoopliveBilliardsClient.cross_reference_kozoom_videos
  # ------------------------------------------------------------------
  test "perform calls SoopliveBilliardsClient.cross_reference_kozoom_videos in Step 3c" do
    kozoom_called = false

    stub_scraping_steps do
      Video::TournamentMatcher.stub(:call, { assigned_count: 0, skipped_count: 0, results: [] }) do
        SoopliveBilliardsClient.stub(:cross_reference_kozoom_videos, -> {
          kozoom_called = true
          { assigned_count: 0 }
        }) do
          DailyInternationalScrapeJob.new.perform
        end
      end
    end

    assert kozoom_called, "Expected SoopliveBilliardsClient.cross_reference_kozoom_videos to be called in Step 3c"
  end

  # ------------------------------------------------------------------
  # Test 3: Errors in matching (Step 3b) do not abort the job
  # ------------------------------------------------------------------
  test "error in Video::TournamentMatcher does not abort the job" do
    stub_scraping_steps do
      Video::TournamentMatcher.stub(:call, -> { raise StandardError, "matcher blew up" }) do
        SoopliveBilliardsClient.stub(:cross_reference_kozoom_videos, { assigned_count: 0 }) do
          assert_nothing_raised do
            DailyInternationalScrapeJob.new.perform
          end
        end
      end
    end
  end

  # ------------------------------------------------------------------
  # Test 4: Errors in Kozoom cross-ref (Step 3c) do not abort the job
  # ------------------------------------------------------------------
  test "error in Kozoom cross-reference does not abort the job" do
    stub_scraping_steps do
      Video::TournamentMatcher.stub(:call, { assigned_count: 0, skipped_count: 0, results: [] }) do
        SoopliveBilliardsClient.stub(:cross_reference_kozoom_videos, -> { raise StandardError, "kozoom blew up" }) do
          assert_nothing_raised do
            DailyInternationalScrapeJob.new.perform
          end
        end
      end
    end
  end

  # ------------------------------------------------------------------
  # Test 5: Return hash includes :matched key
  # ------------------------------------------------------------------
  test "perform return hash includes :matched key" do
    stub_scraping_steps do
      Video::TournamentMatcher.stub(:call, { assigned_count: 3, skipped_count: 1, results: [] }) do
        SoopliveBilliardsClient.stub(:cross_reference_kozoom_videos, { assigned_count: 2 }) do
          result = DailyInternationalScrapeJob.new.perform

          assert result.key?(:matched), "Return hash must include :matched key"
          assert_equal 5, result[:matched], "matched should be TournamentMatcher + Kozoom counts (3 + 2)"
        end
      end
    end
  end

  # ------------------------------------------------------------------
  # Test 6 (integration): Video.unassigned.count decreases when fixture
  # data produces a high-confidence match.
  #
  # Uses real model instances (no mocks for TournamentMatcher/cross_ref)
  # so actual matching logic runs end-to-end against DB fixtures.
  #
  # wc_2024 fixture runs 2024-09-01..2024-09-07, seeded with JASPERS + CHO.
  # jaspers_cho_wc_2024 video published 2024-09-05 with matching title.
  # Expected: Video::TournamentMatcher assigns it (confidence >= 0.75).
  # ------------------------------------------------------------------
  test "Video.unassigned.count decreases after job runs with matching fixture data" do
    # Ensure the fixture video is unassigned before the run
    video = videos(:jaspers_cho_wc_2024)
    video.update_columns(videoable_id: nil, videoable_type: nil)

    before_count = Video.unassigned.count
    assert before_count > 0, "Precondition: at least one unassigned video must exist"

    stub_scraping_steps do
      # cross_reference_kozoom_videos stubbed — Kozoom source not in fixture set
      SoopliveBilliardsClient.stub(:cross_reference_kozoom_videos, { assigned_count: 0 }) do
        DailyInternationalScrapeJob.new.perform
      end
    end

    after_count = Video.unassigned.count
    assert after_count < before_count,
      "Expected Video.unassigned.count to decrease (was #{before_count}, still #{after_count})"
  end
end
