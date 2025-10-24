# frozen_string_literal: true

require "test_helper"

class TournamentSearchTest < ActiveSupport::TestCase
  def setup
    @region = regions(:bbl)
    @season = seasons(:season_2024)
    @discipline = disciplines(:discipline_freie_partie_klein)
    
    @tournament = Tournament.create!(
      title: "Test Stadtmeisterschaft",
      shortname: "TSM2024",
      date: Date.today,
      organizer: @region,
      season: @season,
      discipline: @discipline
    )
    
    TournamentCc.create!(
      tournament: @tournament,
      cc_id: 99999
    )
  end

  test "search_hash returns valid configuration" do
    hash = Tournament.search_hash({ sSearch: "test" })
    
    assert_equal Tournament, hash[:model]
    assert_includes hash.keys, :column_names
    assert_includes hash.keys, :raw_sql
    assert_includes hash.keys, :joins
  end

  test "COLUMN_NAMES includes all required fields" do
    column_names = Tournament::COLUMN_NAMES
    
    # IDs
    assert_equal "tournaments.id", column_names["id"]
    assert_equal "regions.id", column_names["region_id"]
    assert_equal "seasons.id", column_names["season_id"]
    assert_equal "disciplines.id", column_names["discipline_id"]
    
    # Externe IDs
    assert_equal "tournament_ccs.cc_id", column_names["CC_ID"]
    
    # Referenzen
    assert_equal "regions.shortname", column_names["Region"]
    assert_equal "seasons.name", column_names["Season"]
    assert_equal "disciplines.name", column_names["Discipline"]
    
    # Eigene Felder
    assert_equal "tournaments.title", column_names["Title"]
    assert_equal "tournaments.shortname", column_names["Shortname"]
    assert_equal "tournaments.date::date", column_names["Date"]
  end

  test "text_search_sql includes tournament fields" do
    sql = Tournament.text_search_sql
    
    assert_includes sql, "tournaments.title"
    assert_includes sql, "tournaments.shortname"
    assert_includes sql, "seasons.name"
  end

  test "search_joins includes polymorphic organizer" do
    joins = Tournament.search_joins
    
    assert_kind_of Array, joins
    assert joins.any? { |j| j.is_a?(String) && j.include?('organizer_id') }
    assert_includes joins, :season
    assert_includes joins, :discipline
  end

  test "SearchService finds tournament by title" do
    params = { sSearch: "Stadtmeisterschaft" }
    result = SearchService.call(Tournament.search_hash(params))
    
    assert_includes result, @tournament
  end

  test "SearchService finds tournament by shortname" do
    params = { sSearch: "TSM2024" }
    result = SearchService.call(Tournament.search_hash(params))
    
    assert_includes result, @tournament
  end

  test "field_types detects date field" do
    types = Tournament.filter_field_types
    
    assert_equal :date, types["Date"]
  end
end

