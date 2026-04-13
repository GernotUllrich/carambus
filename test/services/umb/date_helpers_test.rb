# frozen_string_literal: true

require "test_helper"

class Umb::DateHelpersTest < ActiveSupport::TestCase
  include Umb::DateHelpers

  # --- parse_date_range ---

  test "parse_date_range returns blank result for nil input" do
    result = Umb::DateHelpers.parse_date_range(nil)
    assert_nil result[:start_date]
    assert_nil result[:end_date]
  end

  test "parse_date_range returns blank result for empty string" do
    result = Umb::DateHelpers.parse_date_range("")
    assert_nil result[:start_date]
    assert_nil result[:end_date]
  end

  test "parse_date_range parses day range with month: '15-17 January 2025'" do
    result = Umb::DateHelpers.parse_date_range("15-17 January 2025")
    assert_equal Date.new(2025, 1, 15), result[:start_date]
    assert_equal Date.new(2025, 1, 17), result[:end_date]
  end

  test "parse_date_range parses day range with abbreviated month: '18-21 Dec 2025'" do
    result = Umb::DateHelpers.parse_date_range("18-21 Dec 2025")
    assert_equal Date.new(2025, 12, 18), result[:start_date]
    assert_equal Date.new(2025, 12, 21), result[:end_date]
  end

  test "parse_date_range parses cross-month range: '28 January - 2 February 2025'" do
    result = Umb::DateHelpers.parse_date_range("28 January - 2 February 2025")
    assert_equal Date.new(2025, 1, 28), result[:start_date]
    assert_equal Date.new(2025, 2, 2), result[:end_date]
  end

  test "parse_date_range handles range with spaces: '15 - 17 Jan 2025'" do
    result = Umb::DateHelpers.parse_date_range("15 - 17 Jan 2025")
    assert_equal Date.new(2025, 1, 15), result[:start_date]
    assert_equal Date.new(2025, 1, 17), result[:end_date]
  end

  # --- parse_single_date ---

  test "parse_single_date returns nil for nil input" do
    assert_nil Umb::DateHelpers.parse_single_date(nil)
  end

  test "parse_single_date parses '15 January 2025'" do
    result = Umb::DateHelpers.parse_single_date("15 January 2025")
    assert_equal Date.new(2025, 1, 15), result
  end

  test "parse_single_date parses '04-November-2024'" do
    result = Umb::DateHelpers.parse_single_date("04-November-2024")
    assert_equal Date.new(2024, 11, 4), result
  end

  test "parse_single_date returns nil for unparseable string" do
    assert_nil Umb::DateHelpers.parse_single_date("not a date")
  end

  # --- parse_month_name ---

  test "parse_month_name returns nil for nil input" do
    assert_nil Umb::DateHelpers.parse_month_name(nil)
  end

  test "parse_month_name parses full month names" do
    assert_equal 1, Umb::DateHelpers.parse_month_name("January")
    assert_equal 12, Umb::DateHelpers.parse_month_name("December")
  end

  test "parse_month_name parses abbreviated month names" do
    assert_equal 1, Umb::DateHelpers.parse_month_name("Jan")
    assert_equal 9, Umb::DateHelpers.parse_month_name("Sept")
    assert_equal 9, Umb::DateHelpers.parse_month_name("Sep")
  end

  test "parse_month_name is case insensitive" do
    assert_equal 3, Umb::DateHelpers.parse_month_name("MARCH")
    assert_equal 6, Umb::DateHelpers.parse_month_name("jun")
  end

  # --- parse_date ---

  test "parse_date parses 04-November-2024 format" do
    result = Umb::DateHelpers.parse_date("04-November-2024")
    assert_equal Date.new(2024, 11, 4), result
  end

  test "parse_date parses ISO format 2025-02-24" do
    result = Umb::DateHelpers.parse_date("2025-02-24")
    assert_equal Date.new(2025, 2, 24), result
  end

  test "parse_date parses European format 24/02/2025" do
    result = Umb::DateHelpers.parse_date("24/02/2025")
    assert_equal Date.new(2025, 2, 24), result
  end

  test "parse_date returns nil for blank input" do
    assert_nil Umb::DateHelpers.parse_date(nil)
    assert_nil Umb::DateHelpers.parse_date("")
  end

  # --- parse_day_range_with_month ---

  test "parse_day_range_with_month handles 'December 18-21, 2025' format" do
    result = Umb::DateHelpers.parse_day_range_with_month("December 18-21, 2025")
    assert_equal Date.new(2025, 12, 18), result[:start_date]
    assert_equal Date.new(2025, 12, 21), result[:end_date]
  end

  test "parse_day_range_with_month returns nil for non-matching string" do
    result = Umb::DateHelpers.parse_day_range_with_month("just text")
    assert_nil result
  end

  # --- parse_month_day_range ---

  test "parse_month_day_range parses cross-month 'Feb 26 - Mar 1, 2026'" do
    result = Umb::DateHelpers.parse_month_day_range("Feb 26 - Mar 1, 2026")
    assert_equal Date.new(2026, 2, 26), result[:start_date]
    assert_equal Date.new(2026, 3, 1), result[:end_date]
  end

  test "parse_month_day_range returns nil for non-matching string" do
    result = Umb::DateHelpers.parse_month_day_range("just text")
    assert_nil result
  end
end
