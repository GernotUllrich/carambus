# frozen_string_literal: true

require "test_helper"

class Umb::PdfParser::PlayerListParserTest < ActiveSupport::TestCase
  FIXTURE_PATH = Rails.root.join("test/fixtures/files/umb_player_list.txt")

  setup do
    @pdf_text = File.read(FIXTURE_PATH)
  end

  # --- parse: basic structure ---

  test "parse returns an array" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    assert_instance_of Array, result
  end

  test "parse returns one hash per player line" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    assert_equal 5, result.size
  end

  test "parse returns hashes with required keys" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    first = result.first
    assert first.key?(:caps_name), "Expected :caps_name key"
    assert first.key?(:mixed_name), "Expected :mixed_name key"
    assert first.key?(:nationality), "Expected :nationality key"
    assert first.key?(:position), "Expected :position key"
  end

  # --- parse: data values ---

  test "parse extracts position as integer" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    assert_equal 1, result[0][:position]
    assert_equal 3, result[2][:position]
  end

  test "parse extracts caps_name (all-caps lastname)" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    assert_equal "JASPERS", result[0][:caps_name]
    assert_equal "CAUDRON", result[1][:caps_name]
  end

  test "parse extracts mixed_name (mixed-case firstname)" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    assert_equal "Dick", result[0][:mixed_name]
    assert_equal "Frederic", result[1][:mixed_name]
  end

  test "parse extracts nationality as string" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    assert_equal "NL", result[0][:nationality]
    assert_equal "BE", result[1][:nationality]
    assert_equal "KR", result[3][:nationality]
  end

  # --- parse: edge cases ---

  test "parse returns empty array for nil input" do
    result = Umb::PdfParser::PlayerListParser.new(nil).parse
    assert_equal [], result
  end

  test "parse returns empty array for empty string" do
    result = Umb::PdfParser::PlayerListParser.new("").parse
    assert_equal [], result
  end

  test "parse skips header lines" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    # No result should have nil position (header lines have no position number)
    result.each do |entry|
      assert_not_nil entry[:position], "Header lines must be skipped"
    end
  end

  test "parse skips malformed lines without crashing" do
    malformed = "1   JASPERS Dick   NL   1   480   0106   Confirmed\nNot a player line\n2   CAUDRON Frederic   BE   2   456   0215   Confirmed\n"
    result = Umb::PdfParser::PlayerListParser.new(malformed).parse
    assert_operator result.size, :>=, 2
  end
end
