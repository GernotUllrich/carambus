# frozen_string_literal: true

require "test_helper"

class SoopliveBilliardsClientTest < ActiveSupport::TestCase
  BILLIARDS_BASE = "https://billiards.sooplive.com"

  setup do
    @client = SoopliveBilliardsClient.new
  end

  # ============================================================
  # Task 1: Basic API client — fetch_games / fetch_matches / fetch_results
  # ============================================================

  test "fetch_games returns parsed JSON array from /api/games" do
    games_json = [
      { "game_no" => 127, "game_name" => "2024 LG U+ Cup 3-Cushion Masters" },
      { "game_no" => 128, "game_name" => "2024 World Cup" }
    ]
    stub_request(:get, "#{BILLIARDS_BASE}/api/games")
      .to_return(status: 200, body: games_json.to_json, headers: { "Content-Type" => "application/json" })

    result = @client.fetch_games

    assert_equal 2, result.size
    assert_equal 127, result.first["game_no"]
    assert_equal "2024 LG U+ Cup 3-Cushion Masters", result.first["game_name"]
  end

  test "fetch_matches returns parsed JSON array from /api/game/{game_no}/matches" do
    matches_json = [
      { "replay_no" => 160553493, "match_no" => 16669, "game_no" => 127,
        "record_yn" => "Y", "player1_name" => "Jaspers", "player2_name" => "Sanchez" }
    ]
    stub_request(:get, "#{BILLIARDS_BASE}/api/game/127/matches")
      .to_return(status: 200, body: matches_json.to_json, headers: { "Content-Type" => "application/json" })

    result = @client.fetch_matches(127)

    assert_equal 1, result.size
    assert_equal 160553493, result.first["replay_no"]
    assert_equal "Y", result.first["record_yn"]
  end

  test "fetch_results returns parsed JSON array from /api/game/{game_no}/results" do
    results_json = [
      { "rank" => 1, "player_name" => "Jaspers", "game_no" => 127 },
      { "rank" => 2, "player_name" => "Sanchez", "game_no" => 127 }
    ]
    stub_request(:get, "#{BILLIARDS_BASE}/api/game/127/results")
      .to_return(status: 200, body: results_json.to_json, headers: { "Content-Type" => "application/json" })

    result = @client.fetch_results(127)

    assert_equal 2, result.size
    assert_equal 1, result.first["rank"]
    assert_equal "Jaspers", result.first["player_name"]
  end

  test "fetch_json returns nil on HTTP 500 error" do
    stub_request(:get, "#{BILLIARDS_BASE}/api/games")
      .to_return(status: 500, body: "Internal Server Error")

    result = @client.fetch_games

    assert_nil result
  end

  test "fetch_json returns nil on network timeout" do
    stub_request(:get, "#{BILLIARDS_BASE}/api/games")
      .to_raise(Net::ReadTimeout)

    result = @client.fetch_games

    assert_nil result
  end

  test "ssl_verify_mode is VERIFY_NONE in test environment" do
    assert_equal OpenSSL::SSL::VERIFY_NONE, @client.send(:ssl_verify_mode)
  end

  test "vod_url class method returns correct VOD URL from replay_no" do
    url = SoopliveBilliardsClient.vod_url(160553493)
    assert_equal "https://vod.sooplive.com/player/160553493", url
  end

  # ============================================================
  # Task 2: VOD linking via replay_no
  # ============================================================

  test "link_match_vods assigns existing Video to InternationalGame by replay_no external_id" do
    source = InternationalSource.create!(name: "SoopLive Test", source_type: "fivesix", active: true)
    season = seasons(:current)
    region = regions(:nbv)

    tournament = InternationalTournament.create!(
      title: "Test Tournament",
      date: Date.today,
      season: season,
      organizer: region,
      organizer_type: "Region",
      international_source: source
    )
    game = InternationalGame.create!(tournament: tournament, seqno: 1)
    video = Video.create!(
      external_id: "160553493",
      title: "Match Video",
      international_source: source
    )

    matches_json = [
      { "replay_no" => 160553493, "match_no" => 16669, "game_no" => 127, "record_yn" => "Y" }
    ]
    stub_request(:get, "#{BILLIARDS_BASE}/api/game/127/matches")
      .to_return(status: 200, body: matches_json.to_json, headers: { "Content-Type" => "application/json" })

    result = @client.link_match_vods(127, international_game: game)
    video.reload

    assert_equal 1, result.size
    assert_equal video.id, result.first[:video_id]
    assert_equal 160553493, result.first[:replay_no]
    assert_equal game, video.videoable
  ensure
    video&.destroy
    game&.destroy
    tournament&.destroy
    source&.destroy
  end

  test "link_match_vods skips matches with replay_no == 0" do
    source = InternationalSource.create!(name: "SoopLive Skip Zero", source_type: "fivesix", active: true)
    season = seasons(:current)
    region = regions(:nbv)

    tournament = InternationalTournament.create!(
      title: "Test Tournament Zero",
      date: Date.today,
      season: season,
      organizer: region,
      organizer_type: "Region",
      international_source: source
    )
    game = InternationalGame.create!(tournament: tournament, seqno: 2)

    matches_json = [
      { "replay_no" => 0, "match_no" => 1, "game_no" => 127, "record_yn" => "Y" }
    ]
    stub_request(:get, "#{BILLIARDS_BASE}/api/game/127/matches")
      .to_return(status: 200, body: matches_json.to_json, headers: { "Content-Type" => "application/json" })

    result = @client.link_match_vods(127, international_game: game)

    assert_equal [], result
  ensure
    game&.destroy
    tournament&.destroy
    source&.destroy
  end

  test "link_match_vods skips matches with record_yn != Y" do
    source = InternationalSource.create!(name: "SoopLive Skip N", source_type: "fivesix", active: true)
    season = seasons(:current)
    region = regions(:nbv)

    tournament = InternationalTournament.create!(
      title: "Test Tournament N",
      date: Date.today,
      season: season,
      organizer: region,
      organizer_type: "Region",
      international_source: source
    )
    game = InternationalGame.create!(tournament: tournament, seqno: 3)

    matches_json = [
      { "replay_no" => 999888777, "match_no" => 2, "game_no" => 127, "record_yn" => "N" }
    ]
    stub_request(:get, "#{BILLIARDS_BASE}/api/game/127/matches")
      .to_return(status: 200, body: matches_json.to_json, headers: { "Content-Type" => "application/json" })

    result = @client.link_match_vods(127, international_game: game)

    assert_equal [], result
  ensure
    game&.destroy
    tournament&.destroy
    source&.destroy
  end

  test "link_match_vods skips already-assigned videos" do
    source = InternationalSource.create!(name: "SoopLive Skip Assigned", source_type: "fivesix", active: true)
    season = seasons(:current)
    region = regions(:nbv)

    tournament = InternationalTournament.create!(
      title: "Test Tournament Assigned",
      date: Date.today,
      season: season,
      organizer: region,
      organizer_type: "Region",
      international_source: source
    )
    game1 = InternationalGame.create!(tournament: tournament, seqno: 4)
    game2 = InternationalGame.create!(tournament: tournament, seqno: 5)

    # Video already assigned to game1
    video = Video.create!(
      external_id: "777666555",
      title: "Already Assigned Video",
      international_source: source,
      videoable: game1
    )

    matches_json = [
      { "replay_no" => 777666555, "match_no" => 3, "game_no" => 127, "record_yn" => "Y" }
    ]
    stub_request(:get, "#{BILLIARDS_BASE}/api/game/127/matches")
      .to_return(status: 200, body: matches_json.to_json, headers: { "Content-Type" => "application/json" })

    result = @client.link_match_vods(127, international_game: game2)
    video.reload

    assert_equal [], result
    assert_equal game1, video.videoable  # Still assigned to original game
  ensure
    video&.destroy
    game1&.destroy
    game2&.destroy
    tournament&.destroy
    source&.destroy
  end

  test "link_match_vods returns array of hash with video_id and replay_no keys" do
    source = InternationalSource.create!(name: "SoopLive Return Type", source_type: "fivesix", active: true)
    season = seasons(:current)
    region = regions(:nbv)

    tournament = InternationalTournament.create!(
      title: "Test Tournament Return",
      date: Date.today,
      season: season,
      organizer: region,
      organizer_type: "Region",
      international_source: source
    )
    game = InternationalGame.create!(tournament: tournament, seqno: 6)
    video = Video.create!(
      external_id: "123456789",
      title: "Return Type Video",
      international_source: source
    )

    matches_json = [
      { "replay_no" => 123456789, "match_no" => 10, "game_no" => 127, "record_yn" => "Y" }
    ]
    stub_request(:get, "#{BILLIARDS_BASE}/api/game/127/matches")
      .to_return(status: 200, body: matches_json.to_json, headers: { "Content-Type" => "application/json" })

    result = @client.link_match_vods(127, international_game: game)

    assert_kind_of Array, result
    assert result.all? { |r| r.key?(:video_id) && r.key?(:replay_no) }
  ensure
    video&.destroy
    game&.destroy
    tournament&.destroy
    source&.destroy
  end

  # ============================================================
  # Task 3: Kozoom eventId cross-referencing
  # ============================================================

  test "cross_reference_kozoom_videos assigns video with eventId to matching InternationalTournament" do
    kozoom_source = InternationalSource.create!(name: "Kozoom Test", source_type: "kozoom", active: true)
    season = seasons(:current)
    region = regions(:nbv)

    tournament = InternationalTournament.create!(
      title: "Kozoom World Cup",
      date: Date.today,
      season: season,
      organizer: region,
      organizer_type: "Region",
      international_source: kozoom_source,
      external_id: "evt_42"
    )
    video = Video.create!(
      external_id: "kz_vid_001",
      title: "Kozoom Video with eventId",
      international_source: kozoom_source,
      data: { "eventId" => "evt_42", "url" => "https://tv.kozoom.com/en/event/evt_42", "player" => "kozoom" }
    )

    result = SoopliveBilliardsClient.cross_reference_kozoom_videos

    assert_equal 1, result[:assigned_count]
    video.reload
    assert_equal tournament, video.videoable
  ensure
    video&.destroy
    tournament&.destroy
    kozoom_source&.destroy
  end

  test "cross_reference_kozoom_videos skips videos without eventId in json_data" do
    kozoom_source = InternationalSource.create!(name: "Kozoom No EventId", source_type: "kozoom", active: true)

    video = Video.create!(
      external_id: "kz_vid_002",
      title: "Kozoom Video without eventId",
      international_source: kozoom_source,
      data: { "url" => "https://tv.kozoom.com/en/event/9999", "player" => "kozoom" }
    )

    result = SoopliveBilliardsClient.cross_reference_kozoom_videos

    assert_equal 0, result[:assigned_count]
    video.reload
    assert_nil video.videoable_id
  ensure
    video&.destroy
    kozoom_source&.destroy
  end

  test "cross_reference_kozoom_videos skips already-assigned videos" do
    kozoom_source = InternationalSource.create!(name: "Kozoom Already Assigned", source_type: "kozoom", active: true)
    season = seasons(:current)
    region = regions(:nbv)

    tournament = InternationalTournament.create!(
      title: "Already Assigned Tournament",
      date: Date.today,
      season: season,
      organizer: region,
      organizer_type: "Region",
      international_source: kozoom_source,
      external_id: "evt_100"
    )
    # Video is already assigned
    video = Video.create!(
      external_id: "kz_vid_003",
      title: "Already Assigned Kozoom Video",
      international_source: kozoom_source,
      data: { "eventId" => "evt_100", "player" => "kozoom" },
      videoable: tournament
    )

    result = SoopliveBilliardsClient.cross_reference_kozoom_videos

    assert_equal 0, result[:assigned_count]
  ensure
    video&.destroy
    tournament&.destroy
    kozoom_source&.destroy
  end

  test "cross_reference_kozoom_videos returns assigned_count" do
    kozoom_source = InternationalSource.create!(name: "Kozoom Count", source_type: "kozoom", active: true)
    season = seasons(:current)
    region = regions(:nbv)

    tournament1 = InternationalTournament.create!(
      title: "Kozoom Tourney A",
      date: Date.today,
      season: season,
      organizer: region,
      organizer_type: "Region",
      international_source: kozoom_source,
      external_id: "evt_A"
    )
    tournament2 = InternationalTournament.create!(
      title: "Kozoom Tourney B",
      date: Date.today,
      season: season,
      organizer: region,
      organizer_type: "Region",
      international_source: kozoom_source,
      external_id: "evt_B"
    )
    video1 = Video.create!(
      external_id: "kz_vid_a1",
      title: "Kozoom A Video",
      international_source: kozoom_source,
      data: { "eventId" => "evt_A", "player" => "kozoom" }
    )
    video2 = Video.create!(
      external_id: "kz_vid_b1",
      title: "Kozoom B Video",
      international_source: kozoom_source,
      data: { "eventId" => "evt_B", "player" => "kozoom" }
    )

    result = SoopliveBilliardsClient.cross_reference_kozoom_videos

    assert_equal 2, result[:assigned_count]
  ensure
    video1&.destroy
    video2&.destroy
    tournament1&.destroy
    tournament2&.destroy
    kozoom_source&.destroy
  end

  test "cross_reference_kozoom_videos gracefully returns 0 when no Kozoom source exists" do
    result = SoopliveBilliardsClient.cross_reference_kozoom_videos

    assert_kind_of Hash, result
    assert result.key?(:assigned_count)
    assert result[:assigned_count] >= 0
  end
end
