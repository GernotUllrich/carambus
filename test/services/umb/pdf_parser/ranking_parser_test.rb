# frozen_string_literal: true

require "test_helper"

# NOTE: Fixture format constructed from V1's scrape_results_from_pdf regex pattern
# and known UMB PDF structures. Verify against a real downloaded PDF if available.
class Umb::PdfParser::RankingParserTest < ActiveSupport::TestCase
  FINAL_FIXTURE_PATH = Rails.root.join("test/fixtures/files/umb_final_ranking.txt")
  WEEKLY_FIXTURE_PATH = Rails.root.join("test/fixtures/files/umb_weekly_ranking.txt")

  setup do
    @final_text = File.read(FINAL_FIXTURE_PATH)
    @weekly_text = File.read(WEEKLY_FIXTURE_PATH)
  end

  # --- :final type ---

  test "parse returns array for final type" do
    result = Umb::PdfParser::RankingParser.new(@final_text, type: :final).parse
    assert_instance_of Array, result
  end

  test "parse returns one hash per ranked player for final type" do
    result = Umb::PdfParser::RankingParser.new(@final_text, type: :final).parse
    assert_equal 4, result.size
  end

  test "parse returns hashes with required keys for final type" do
    result = Umb::PdfParser::RankingParser.new(@final_text, type: :final).parse
    first = result.first
    assert first.key?(:position), "Expected :position key"
    assert first.key?(:player_name), "Expected :player_name key"
    assert first.key?(:nationality), "Expected :nationality key"
    assert first.key?(:points), "Expected :points key"
    assert first.key?(:average), "Expected :average key"
  end

  test "parse extracts position as integer for final type" do
    result = Umb::PdfParser::RankingParser.new(@final_text, type: :final).parse
    assert_equal 1, result[0][:position]
    assert_equal 2, result[1][:position]
    assert_equal 4, result[3][:position]
  end

  test "parse extracts player_name for final type" do
    result = Umb::PdfParser::RankingParser.new(@final_text, type: :final).parse
    assert_equal "JASPERS Dick", result[0][:player_name]
    assert_equal "CAUDRON Frederic", result[1][:player_name]
  end

  test "parse extracts nationality for final type" do
    result = Umb::PdfParser::RankingParser.new(@final_text, type: :final).parse
    assert_equal "NL", result[0][:nationality]
    assert_equal "BE", result[1][:nationality]
  end

  test "parse extracts points as integer for final type" do
    result = Umb::PdfParser::RankingParser.new(@final_text, type: :final).parse
    assert_equal 150, result[0][:points]
    assert_equal 140, result[1][:points]
  end

  test "parse extracts average as float for final type" do
    result = Umb::PdfParser::RankingParser.new(@final_text, type: :final).parse
    assert_in_delta 2.500, result[0][:average], 0.001
    assert_in_delta 2.153, result[1][:average], 0.001
  end

  # --- :weekly type ---

  test "parse returns array for weekly type" do
    result = Umb::PdfParser::RankingParser.new(@weekly_text, type: :weekly).parse
    assert_instance_of Array, result
  end

  test "parse returns one hash per ranked player for weekly type" do
    result = Umb::PdfParser::RankingParser.new(@weekly_text, type: :weekly).parse
    assert_equal 5, result.size
  end

  test "parse returns hashes with required keys for weekly type" do
    result = Umb::PdfParser::RankingParser.new(@weekly_text, type: :weekly).parse
    first = result.first
    assert first.key?(:rank), "Expected :rank key"
    assert first.key?(:player_name), "Expected :player_name key"
    assert first.key?(:nationality), "Expected :nationality key"
    assert first.key?(:points), "Expected :points key"
  end

  test "parse extracts rank as integer for weekly type" do
    result = Umb::PdfParser::RankingParser.new(@weekly_text, type: :weekly).parse
    assert_equal 1, result[0][:rank]
    assert_equal 3, result[2][:rank]
  end

  test "parse extracts player_name for weekly type" do
    result = Umb::PdfParser::RankingParser.new(@weekly_text, type: :weekly).parse
    assert_equal "JASPERS Dick", result[0][:player_name]
    assert_equal "SIDHOM Haytham", result[4][:player_name]
  end

  test "parse extracts nationality for weekly type" do
    result = Umb::PdfParser::RankingParser.new(@weekly_text, type: :weekly).parse
    assert_equal "NL", result[0][:nationality]
    assert_equal "EG", result[4][:nationality]
  end

  test "parse extracts points as integer for weekly type" do
    result = Umb::PdfParser::RankingParser.new(@weekly_text, type: :weekly).parse
    assert_equal 1200, result[0][:points]
    assert_equal 1000, result[4][:points]
  end

  # --- default type ---

  test "default type is :final" do
    result_with_default = Umb::PdfParser::RankingParser.new(@final_text).parse
    result_explicit = Umb::PdfParser::RankingParser.new(@final_text, type: :final).parse
    assert_equal result_explicit, result_with_default
  end

  # --- edge cases ---

  test "parse returns empty array for nil input" do
    result = Umb::PdfParser::RankingParser.new(nil).parse
    assert_equal [], result
  end

  test "parse returns empty array for empty string" do
    result = Umb::PdfParser::RankingParser.new("").parse
    assert_equal [], result
  end

  test "parse skips header rows" do
    result = Umb::PdfParser::RankingParser.new(@final_text, type: :final).parse
    result.each do |entry|
      assert_not_nil entry[:position], "Header rows must be skipped"
    end
  end

  test "no reference to InternationalResult in parser" do
    source = File.read(Rails.root.join("app/services/umb/pdf_parser/ranking_parser.rb"))
    assert_no_match(/InternationalResult/, source)
  end
end
