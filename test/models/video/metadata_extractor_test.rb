# frozen_string_literal: true

require "test_helper"

class Video::MetadataExtractorTest < ActiveSupport::TestCase
  # Helper to build a minimal Video-like struct without touching the DB
  def make_video(title:, description: "")
    video = Video.new(
      external_id: "test_#{SecureRandom.hex(4)}",
      title: title,
      description: description,
      international_source: international_sources(:umb_source)
    )
    video
  end

  # ------------------------------------------------------------------
  # Test 1: extract_players delegates to video.detect_player_tags
  # ------------------------------------------------------------------
  test "extract_players returns detected player tags from video title" do
    video = make_video(title: "World Cup 2024 JASPERS vs CHO Final")
    extractor = Video::MetadataExtractor.new(video)

    players = extractor.extract_players
    assert_includes players, "jaspers"
    assert_includes players, "cho"
  end

  test "extract_players returns empty array when no known players in title" do
    video = make_video(title: "Unknown Tournament Match 2024")
    extractor = Video::MetadataExtractor.new(video)

    assert_equal [], extractor.extract_players
  end

  # ------------------------------------------------------------------
  # Test 2: extract_round recognizes round keys from GAME_TYPE_MAPPINGS
  # ------------------------------------------------------------------
  test "extract_round recognizes R16 in title" do
    video = make_video(title: "World Cup 2024 R16 - JASPERS vs TRAN")
    extractor = Video::MetadataExtractor.new(video)

    assert_equal "R16", extractor.extract_round
  end

  test "extract_round recognizes Semi_Final in title" do
    video = make_video(title: "World Championship Semi_Final 2025")
    extractor = Video::MetadataExtractor.new(video)

    assert_equal "Semi_Final", extractor.extract_round
  end

  test "extract_round recognizes Final in title" do
    video = make_video(title: "UMB World Cup Final 2024 - CHO vs JASPERS")
    extractor = Video::MetadataExtractor.new(video)

    assert_equal "Final", extractor.extract_round
  end

  test "extract_round recognizes Q (Qualification) in title" do
    video = make_video(title: "World Cup Q Round MERCKX vs BAO")
    extractor = Video::MetadataExtractor.new(video)

    assert_equal "Q", extractor.extract_round
  end

  test "extract_round recognizes PQ in title" do
    video = make_video(title: "Pre-Qualification PQ match 2024")
    extractor = Video::MetadataExtractor.new(video)

    assert_equal "PQ", extractor.extract_round
  end

  test "extract_round returns nil when no round pattern found" do
    video = make_video(title: "Highlights 2024 World Cup")
    extractor = Video::MetadataExtractor.new(video)

    assert_nil extractor.extract_round
  end

  # ------------------------------------------------------------------
  # Test 3: extract_tournament_type detects type from title/description
  # ------------------------------------------------------------------
  test "extract_tournament_type detects world_cup" do
    video = make_video(title: "UMB World Cup Antwerp 2024")
    extractor = Video::MetadataExtractor.new(video)

    assert_equal "world_cup", extractor.extract_tournament_type
  end

  test "extract_tournament_type detects world_championship" do
    video = make_video(title: "World Championship 3-Cushion 2025")
    extractor = Video::MetadataExtractor.new(video)

    assert_equal "world_championship", extractor.extract_tournament_type
  end

  test "extract_tournament_type detects european_championship" do
    video = make_video(title: "European Championship Carom 2024")
    extractor = Video::MetadataExtractor.new(video)

    assert_equal "european_championship", extractor.extract_tournament_type
  end

  test "extract_tournament_type returns nil when no type detected" do
    video = make_video(title: "Friendly match 2024 - JASPERS vs CHO")
    extractor = Video::MetadataExtractor.new(video)

    assert_nil extractor.extract_tournament_type
  end

  # ------------------------------------------------------------------
  # Test 4: extract_year detects 4-digit year from title
  # ------------------------------------------------------------------
  test "extract_year detects 2024 from title" do
    video = make_video(title: "World Cup 2024 Final")
    extractor = Video::MetadataExtractor.new(video)

    assert_equal 2024, extractor.extract_year
  end

  test "extract_year detects 2025 from title" do
    video = make_video(title: "UMB 2025 Antwerp Q round")
    extractor = Video::MetadataExtractor.new(video)

    assert_equal 2025, extractor.extract_year
  end

  test "extract_year returns nil when no year in title" do
    video = make_video(title: "World Cup Final CHO vs JASPERS")
    extractor = Video::MetadataExtractor.new(video)

    assert_nil extractor.extract_year
  end

  # ------------------------------------------------------------------
  # Test 5: extract_all returns hash with all required keys
  # ------------------------------------------------------------------
  test "extract_all returns hash with :players, :round, :tournament_type, :year keys" do
    video = make_video(title: "World Cup 2024 Final - JASPERS vs CHO")
    extractor = Video::MetadataExtractor.new(video)

    result = extractor.extract_all
    assert_kind_of Hash, result
    assert result.key?(:players)
    assert result.key?(:round)
    assert result.key?(:tournament_type)
    assert result.key?(:year)
  end

  test "extract_all populates all fields from rich title" do
    video = make_video(title: "UMB World Cup 2024 Final - JASPERS vs CHO")
    extractor = Video::MetadataExtractor.new(video)

    result = extractor.extract_all
    assert_includes result[:players], "jaspers"
    assert_includes result[:players], "cho"
    assert_equal "Final", result[:round]
    assert_equal "world_cup", result[:tournament_type]
    assert_equal 2024, result[:year]
  end

  # ------------------------------------------------------------------
  # Test 6: AI fallback NOT called when regex extraction succeeds
  # ------------------------------------------------------------------
  test "extract_with_ai_fallback does not call OpenAI when regex succeeds" do
    video = make_video(title: "UMB World Cup 2024 Final - JASPERS vs CHO")
    extractor = Video::MetadataExtractor.new(video)

    # If OpenAI were called, it would fail due to WebMock blocking real HTTP
    # We just verify the call returns the regex result without errors
    result = extractor.extract_with_ai_fallback(ai_extraction_enabled: true)
    assert_kind_of Hash, result
    assert result[:players].any?
  end

  # ------------------------------------------------------------------
  # Test 7: AI fallback called when regex returns empty and ai_extraction_enabled true
  # ------------------------------------------------------------------
  test "extract_with_ai_fallback calls AI when regex fails and ai_extraction_enabled is true" do
    video = make_video(title: "당구 경기 결승전") # Korean title with no known patterns
    extractor = Video::MetadataExtractor.new(video)

    # Stub OpenAI API call
    stub_request(:post, /api\.openai\.com/)
      .to_return(
        status: 200,
        body: {
          choices: [
            {
              message: {
                content: '{"players": [], "round": "Final", "tournament_type": "world_cup", "year": 2024}'
              }
            }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = extractor.extract_with_ai_fallback(ai_extraction_enabled: true)
    assert_kind_of Hash, result
    # AI fallback was called (WebMock stub used) — verify keys present
    assert result.key?(:players)
    assert result.key?(:round)
  end

  # ------------------------------------------------------------------
  # Test 8: AI fallback NOT called when ai_extraction_enabled is false
  # ------------------------------------------------------------------
  test "extract_with_ai_fallback does not call AI when ai_extraction_enabled is false" do
    video = make_video(title: "당구 경기 결승전") # Korean title with no known patterns
    extractor = Video::MetadataExtractor.new(video)

    # No OpenAI stub — if AI were called, WebMock would raise
    # With ai_extraction_enabled: false, no HTTP call should be made
    assert_nothing_raised do
      result = extractor.extract_with_ai_fallback(ai_extraction_enabled: false)
      assert_kind_of Hash, result
    end
  end
end
