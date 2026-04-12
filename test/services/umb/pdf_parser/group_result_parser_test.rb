# frozen_string_literal: true

require "test_helper"

class Umb::PdfParser::GroupResultParserTest < ActiveSupport::TestCase
  FIXTURE_PATH = Rails.root.join("test/fixtures/files/umb_group_results.txt")

  setup do
    @pdf_text = File.read(FIXTURE_PATH)
  end

  # --- parse: basic structure ---

  test "parse returns an array" do
    result = Umb::PdfParser::GroupResultParser.new(@pdf_text).parse
    assert_instance_of Array, result
  end

  test "parse returns one hash per match pair" do
    result = Umb::PdfParser::GroupResultParser.new(@pdf_text).parse
    assert_equal 3, result.size
  end

  test "parse returns hashes with required keys" do
    result = Umb::PdfParser::GroupResultParser.new(@pdf_text).parse
    first = result.first
    assert first.key?(:group), "Expected :group key"
    assert first.key?(:player_a), "Expected :player_a key"
    assert first.key?(:player_b), "Expected :player_b key"
    assert first.key?(:winner_name), "Expected :winner_name key"
  end

  test "player_a and player_b have required stat keys" do
    result = Umb::PdfParser::GroupResultParser.new(@pdf_text).parse
    player_a = result.first[:player_a]
    %i[name nationality points innings average hs match_points].each do |key|
      assert player_a.key?(key), "Expected player_a to have :#{key}"
    end
  end

  # --- parse: group detection ---

  test "parse assigns correct group letter" do
    result = Umb::PdfParser::GroupResultParser.new(@pdf_text).parse
    assert_equal "A", result[0][:group]
    assert_equal "A", result[1][:group]
    assert_equal "B", result[2][:group]
  end

  # --- parse: player data ---

  test "parse extracts player names" do
    result = Umb::PdfParser::GroupResultParser.new(@pdf_text).parse
    first = result.first
    assert_equal "JASPERS Dick", first[:player_a][:name]
    assert_equal "CAUDRON Frederic", first[:player_b][:name]
  end

  test "parse extracts points as integers" do
    result = Umb::PdfParser::GroupResultParser.new(@pdf_text).parse
    assert_equal 30, result[0][:player_a][:points]
    assert_equal 25, result[0][:player_b][:points]
  end

  test "parse extracts innings as integers" do
    result = Umb::PdfParser::GroupResultParser.new(@pdf_text).parse
    assert_equal 14, result[0][:player_a][:innings]
    assert_equal 18, result[0][:player_b][:innings]
  end

  test "parse extracts average as float" do
    result = Umb::PdfParser::GroupResultParser.new(@pdf_text).parse
    assert_in_delta 2.142, result[0][:player_a][:average], 0.001
    assert_in_delta 1.388, result[0][:player_b][:average], 0.001
  end

  test "parse extracts match_points as integers" do
    result = Umb::PdfParser::GroupResultParser.new(@pdf_text).parse
    assert_equal 2, result[0][:player_a][:match_points]
    assert_equal 0, result[0][:player_b][:match_points]
  end

  # --- parse: winner identification ---

  test "parse identifies winner as player with higher match_points" do
    result = Umb::PdfParser::GroupResultParser.new(@pdf_text).parse
    # JASPERS has 2 match_points vs CAUDRON's 0
    assert_equal "JASPERS Dick", result[0][:winner_name]
  end

  test "parse identifies winner in second group" do
    result = Umb::PdfParser::GroupResultParser.new(@pdf_text).parse
    # SIDHOM has 2 match_points vs JEONGU's 0
    assert_equal "SIDHOM Haytham", result[2][:winner_name]
  end

  # --- parse: edge cases ---

  test "parse returns empty array for nil input" do
    result = Umb::PdfParser::GroupResultParser.new(nil).parse
    assert_equal [], result
  end

  test "parse returns empty array for empty string" do
    result = Umb::PdfParser::GroupResultParser.new("").parse
    assert_equal [], result
  end

  test "parse skips header and label lines" do
    result = Umb::PdfParser::GroupResultParser.new(@pdf_text).parse
    result.each do |match|
      # No match should have nil group
      assert_not_nil match[:group], "Header/label lines must be skipped"
    end
  end

  test "uses pair-accumulator pattern — pending_player reset on new group" do
    # Two groups with odd player counts should not bleed across groups
    text = "Group A\n\nJASPERS Dick   30   14   2.142   2   9   4\n\nGroup B\n\nSIDHOM Haytham   30   16   1.875   2   10   6\nJEONGU Park   28   20   1.400   0   8   5\n"
    result = Umb::PdfParser::GroupResultParser.new(text).parse
    # Group B match should have correct group label (not A)
    assert result.any? { |m| m[:group] == "B" }, "Group B match must be present"
    result.select { |m| m[:group] == "B" }.each do |match|
      assert_equal "B", match[:group]
    end
  end
end
