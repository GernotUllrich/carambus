# frozen_string_literal: true

require "test_helper"

class LocationSearchTest < ActiveSupport::TestCase
  def setup
    @region = regions(:bbl)
    @club = clubs(:club_bochum)
    
    @location = Location.create!(
      name: "Test Vereinsheim",
      address: "Teststraße 123, Berlin",
      organizer: @club
    )
    
    ClubLocation.create!(club: @club, location: @location)
  end

  test "search_hash returns valid configuration" do
    hash = Location.search_hash({ sSearch: "test" })
    
    assert_equal Location, hash[:model]
    assert_includes hash.keys, :column_names
    assert_includes hash.keys, :raw_sql
    assert_includes hash.keys, :joins
  end

  test "COLUMN_NAMES includes all required fields" do
    column_names = Location::COLUMN_NAMES
    
    # IDs
    assert_equal "locations.id", column_names["id"]
    assert_equal "regions.id", column_names["region_id"]
    assert_equal "clubs.id", column_names["club_id"]
    
    # Referenzen
    assert_equal "regions.shortname", column_names["Region"]
    assert_equal "clubs.shortname", column_names["Club"]
    
    # Eigene Felder
    assert_equal "locations.name", column_names["Name"]
    assert_equal "locations.address", column_names["Address"]
  end

  test "text_search_sql includes location fields" do
    sql = Location.text_search_sql
    
    assert_includes sql, "locations.name"
    assert_includes sql, "locations.address"
    assert_includes sql, "locations.synonyms"
    assert_includes sql, "clubs.shortname"
  end

  test "search_joins uses LEFT OUTER JOIN" do
    joins = Location.search_joins
    
    assert_kind_of Array, joins
    assert joins.any? { |j| j.include?('LEFT OUTER JOIN') }
  end

  test "cascading_filters includes region to club" do
    filters = Location.cascading_filters
    
    assert_equal ['club_id'], filters['region_id']
  end

  test "SearchService finds location by name" do
    params = { sSearch: "Vereinsheim" }
    result = SearchService.call(Location.search_hash(params))
    
    assert_includes result, @location
  end

  test "SearchService finds location by address" do
    params = { sSearch: "Berlin" }
    result = SearchService.call(Location.search_hash(params))
    
    assert_includes result, @location
  end
end

