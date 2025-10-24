# frozen_string_literal: true

require "test_helper"

class ClubSearchTest < ActiveSupport::TestCase
  def setup
    @region = regions(:bbl)
    
    @club = Club.create!(
      shortname: "Test BC",
      name: "Test Billard Club",
      address: "Clubstraße 1, Bochum",
      email: "info@test-bc.de",
      homepage: "www.test-bc.de",
      ba_id: 12345,
      cc_id: 67890,
      region: @region,
      status: "active",
      founded: "1950"
    )
  end

  test "search_hash returns valid configuration" do
    hash = Club.search_hash({ sSearch: "test" })
    
    assert_equal Club, hash[:model]
    assert_includes hash.keys, :column_names
    assert_includes hash.keys, :raw_sql
    assert_includes hash.keys, :joins
  end

  test "COLUMN_NAMES includes all required fields" do
    column_names = Club::COLUMN_NAMES
    
    # IDs
    assert_equal "clubs.id", column_names["id"]
    assert_equal "clubs.region_id", column_names["region_id"]
    
    # Externe IDs
    assert_equal "clubs.ba_id", column_names["BA_ID"]
    assert_equal "clubs.cc_id", column_names["CC_ID"]
    
    # Referenzen
    assert_equal "regions.shortname", column_names["Region"]
    
    # Eigene Felder
    assert_equal "clubs.shortname", column_names["Name"]
    assert_equal "clubs.address", column_names["Address"]
    assert_equal "clubs.email", column_names["Email"]
    assert_equal "clubs.homepage", column_names["Homepage"]
    assert_equal "clubs.status", column_names["Status"]
    assert_equal "clubs.founded", column_names["Founded"]
  end

  test "text_search_sql includes club fields" do
    sql = Club.text_search_sql
    
    assert_includes sql, "clubs.shortname"
    assert_includes sql, "clubs.address"
    assert_includes sql, "clubs.email"
    assert_includes sql, "clubs.cc_id"
    assert_includes sql, "regions.shortname"
  end

  test "search_joins includes region" do
    joins = Club.search_joins
    
    assert_equal [:region], joins
  end

  test "cascading_filters is empty" do
    filters = Club.cascading_filters
    
    assert_empty filters
  end

  test "SearchService finds club by shortname" do
    params = { sSearch: "Test BC" }
    result = SearchService.call(Club.search_hash(params))
    
    assert_includes result, @club
  end

  test "SearchService finds club by address" do
    params = { sSearch: "Bochum" }
    result = SearchService.call(Club.search_hash(params))
    
    assert_includes result, @club
  end

  test "SearchService finds club by CC_ID" do
    params = { sSearch: "cc_id:67890" }
    result = SearchService.call(Club.search_hash(params))
    
    assert_includes result, @club
  end
end

