# frozen_string_literal: true

require "test_helper"

# Tests for Video::TournamentMatcher ApplicationService.
#
# Uses database records (fixtures) since the matcher calls
# InternationalTournament.where, Video.unassigned, and video.update.
#
# STI note: InternationalTournament fixtures live in tournaments.yml.
# Access them via tournaments(:label) — Rails does not generate
# `international_tournaments` accessors for STI subclasses.
class Video::TournamentMatcherTest < ActiveSupport::TestCase
  # ------------------------------------------------------------------
  # Test 1: No unassigned videos → { assigned_count: 0, skipped_count: 0 }
  # ------------------------------------------------------------------
  test "call with no unassigned videos returns zero counts" do
    result = Video::TournamentMatcher.call(video_scope: Video.none)
    assert_equal 0, result[:assigned_count]
    assert_equal 0, result[:skipped_count]
    assert_equal [], result[:results]
  end

  # ------------------------------------------------------------------
  # Test 2: High-confidence match → assigned
  # ------------------------------------------------------------------
  test "video with date overlap and matching players gets assigned above threshold" do
    tournament = tournaments(:wc_2024)
    video = videos(:jaspers_cho_wc_2024)

    result = Video::TournamentMatcher.call(video_scope: Video.where(id: video.id))

    assert_equal 1, result[:assigned_count], "Expected video to be assigned"
    assert_equal 0, result[:skipped_count]
    video.reload
    assert_equal tournament, video.videoable
  end

  # ------------------------------------------------------------------
  # Test 3: No date overlap → below threshold, NOT assigned
  # ------------------------------------------------------------------
  test "video with no date overlap is not assigned" do
    video = videos(:no_date_overlap_video)

    result = Video::TournamentMatcher.call(video_scope: Video.where(id: video.id))

    assert_equal 0, result[:assigned_count]
    assert_equal 1, result[:skipped_count]
    video.reload
    assert_nil video.videoable_id
  end

  # ------------------------------------------------------------------
  # Test 4: Assignment uses video.update(videoable: tournament)
  #         Rails polymorphic + STI stores base class name "Tournament".
  #         The important thing: videoable resolves to an InternationalTournament.
  # ------------------------------------------------------------------
  test "assignment resolves videoable to the correct InternationalTournament record" do
    tournament = tournaments(:wc_2024)
    video = videos(:jaspers_cho_wc_2024)
    Video::TournamentMatcher.call(video_scope: Video.where(id: video.id))

    video.reload
    # Rails STI + polymorphic stores base class name "Tournament"
    assert_equal "Tournament", video.videoable_type
    assert_equal tournament.id, video.videoable_id
    # Ensure the videoable is actually an InternationalTournament instance
    assert_instance_of InternationalTournament, video.videoable
  end

  # ------------------------------------------------------------------
  # Test 5: Already-assigned video is skipped
  # ------------------------------------------------------------------
  test "already assigned video is skipped" do
    video = videos(:already_assigned_video)

    result = Video::TournamentMatcher.call(video_scope: Video.where(id: video.id))

    assert_equal 0, result[:assigned_count]
    assert_equal 1, result[:skipped_count]
  end

  # ------------------------------------------------------------------
  # Test 6: nil end_date falls back to date + 7.days
  # ------------------------------------------------------------------
  test "tournament with nil end_date uses date plus 7 days as range" do
    tournament = tournaments(:wc_no_end_date)
    video = videos(:video_within_7day_range)

    result = Video::TournamentMatcher.call(video_scope: Video.where(id: video.id))

    assert_equal 1, result[:assigned_count], "Video within 7-day fallback range should be assigned"
    video.reload
    assert_equal tournament, video.videoable
  end

  # ------------------------------------------------------------------
  # Test 7: Returns hash with :assigned_count, :skipped_count, :results keys
  # ------------------------------------------------------------------
  test "call returns hash with assigned_count, skipped_count, results keys" do
    result = Video::TournamentMatcher.call(video_scope: Video.none)
    assert result.key?(:assigned_count)
    assert result.key?(:skipped_count)
    assert result.key?(:results)
    assert_kind_of Array, result[:results]
  end

  # ------------------------------------------------------------------
  # Test 8: confidence_score returns float between 0.0 and 1.0
  # ------------------------------------------------------------------
  test "confidence_score returns float between 0.0 and 1.0" do
    tournament = tournaments(:wc_2024)
    video = videos(:jaspers_cho_wc_2024)
    matcher = Video::TournamentMatcher.new

    score = matcher.confidence_score(video, tournament)
    assert_kind_of Float, score
    assert score >= 0.0, "Score should be >= 0.0, got #{score}"
    assert score <= 1.0, "Score should be <= 1.0, got #{score}"
  end

  test "confidence_score for date-overlapping high-player-match video is above 0.75" do
    tournament = tournaments(:wc_2024)
    video = videos(:jaspers_cho_wc_2024)
    matcher = Video::TournamentMatcher.new

    score = matcher.confidence_score(video, tournament)
    assert score >= 0.75, "Expected score >= 0.75, got #{score}"
  end

  test "confidence_score for video with no overlap is below 0.75" do
    tournament = tournaments(:wc_2024)
    video = videos(:no_date_overlap_video)
    matcher = Video::TournamentMatcher.new

    score = matcher.confidence_score(video, tournament)
    assert score < 0.75, "Expected score < 0.75, got #{score}"
  end
end
