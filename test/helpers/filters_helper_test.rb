# frozen_string_literal: true

require "test_helper"

class FiltersHelperTest < ActionView::TestCase
  include FiltersHelper

  test "parse_search_terms splits simple terms" do
    result = parse_search_terms("Meyer Hamburg")
    assert_equal ["Meyer", "Hamburg"], result
  end

  test "parse_search_terms handles field:value pairs" do
    result = parse_search_terms("Region:HH Season:2024/2025")
    assert_equal ["Region:HH", "Season:2024/2025"], result
  end

  test "parse_search_terms respects double quoted values" do
    result = parse_search_terms('Location:"BC Wedel" Season:2025/2026')
    assert_equal ["Location:BC Wedel", "Season:2025/2026"], result
  end

  test "parse_search_terms respects single quoted values" do
    result = parse_search_terms("Location:'BC Wedel' Season:2025/2026")
    assert_equal ["Location:BC Wedel", "Season:2025/2026"], result
  end

  test "parse_search_terms handles quoted discipline names" do
    result = parse_search_terms('Discipline:"Freie Partie" Region:HH')
    assert_equal ["Discipline:Freie Partie", "Region:HH"], result
  end

  test "parse_search_terms handles mixed quoted and unquoted" do
    result = parse_search_terms('Location:"BC Wedel" Meyer Season:2024/2025')
    assert_equal ["Location:BC Wedel", "Meyer", "Season:2024/2025"], result
  end

  test "parse_search_terms handles comma separators" do
    result = parse_search_terms("Meyer,Hamburg,2024")
    assert_equal ["Meyer", "Hamburg", "2024"], result
  end

  test "parse_search_terms handles ampersand separators" do
    result = parse_search_terms("Region:HH&Season:2024/2025")
    assert_equal ["Region:HH", "Season:2024/2025"], result
  end

  test "parse_search_terms removes empty terms" do
    result = parse_search_terms("Meyer   Hamburg    2024")
    assert_equal ["Meyer", "Hamburg", "2024"], result
  end

  test "parse_search_terms handles complex real-world example" do
    result = parse_search_terms('Location:"BC Wedel" Season:2025/2026 Discipline:"Freie Partie"')
    assert_equal ["Location:BC Wedel", "Season:2025/2026", "Discipline:Freie Partie"], result
  end

  test "parse_search_terms returns empty array for blank string" do
    result = parse_search_terms("")
    assert_equal [], result
  end

  test "parse_search_terms returns empty array for nil" do
    result = parse_search_terms(nil)
    assert_equal [], result
  end

  test "parse_search_terms handles unquoted values with spaces (backwards compatible)" do
    # This should split on spaces (backwards compatible behavior)
    result = parse_search_terms("Location:BC Wedel Season:2025/2026")
    assert_equal ["Location:BC", "Wedel", "Season:2025/2026"], result
  end
end

