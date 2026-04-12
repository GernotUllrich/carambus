# frozen_string_literal: true

require "test_helper"

# Tests for the assign_videos_to_tournament fix (SCRP-03).
# Verifies that video assignment uses the polymorphic videoable association,
# not the non-existent international_tournament_id column.
class TournamentDiscoveryServiceTest < ActiveSupport::TestCase
  setup do
    @service = TournamentDiscoveryService.new

    # Reuse fixtures for season + organizer
    @season = seasons(:current)
    @region = regions(:nbv)

    # Create an InternationalSource for Video (required association)
    @source = InternationalSource.create!(
      name: "Test UMB Source",
      source_type: "umb",
      active: true
    )

    # Create an InternationalTournament (STI on Tournament)
    @tournament = InternationalTournament.create!(
      title: "World Cup Test 2024",
      date: Date.today,
      season: @season,
      organizer: @region,
      organizer_type: "Region",
      international_source: @source
    )
  end

  teardown do
    Video.where(international_source: @source).destroy_all
    @tournament.destroy
    @source.destroy
  end

  test "assign_videos_to_tournament updates video.videoable to the tournament" do
    video = Video.create!(
      external_id: "yt_test_001",
      title: "World Cup Match Video",
      international_source: @source
    )

    candidate = { videos: [video] }
    @service.send(:assign_videos_to_tournament, @tournament, candidate)

    video.reload
    assert_equal @tournament, video.videoable
  end

  test "assign_videos_to_tournament increments @videos_assigned counter" do
    video = Video.create!(
      external_id: "yt_test_002",
      title: "World Cup Finals Video",
      international_source: @source
    )

    candidate = { videos: [video] }
    assert_equal 0, @service.videos_assigned

    @service.send(:assign_videos_to_tournament, @tournament, candidate)

    assert_equal 1, @service.videos_assigned
  end

  test "assign_videos_to_tournament skips videos already assigned to the same tournament" do
    video = Video.create!(
      external_id: "yt_test_003",
      title: "Already Assigned Video",
      international_source: @source,
      videoable: @tournament
    )

    candidate = { videos: [video] }
    @service.send(:assign_videos_to_tournament, @tournament, candidate)

    assert_equal 0, @service.videos_assigned
    video.reload
    assert_equal @tournament, video.videoable
  end

  test "assign_videos_to_tournament reassigns video from different tournament" do
    other_tournament = InternationalTournament.create!(
      title: "Other World Cup 2024",
      date: Date.today,
      season: @season,
      organizer: @region,
      organizer_type: "Region",
      international_source: @source
    )

    video = Video.create!(
      external_id: "yt_test_004",
      title: "Video Assigned Elsewhere",
      international_source: @source,
      videoable: other_tournament
    )

    candidate = { videos: [video] }
    @service.send(:assign_videos_to_tournament, @tournament, candidate)

    video.reload
    assert_equal @tournament, video.videoable
    assert_equal 1, @service.videos_assigned

    other_tournament.destroy
  end
end
