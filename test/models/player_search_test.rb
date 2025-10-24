# frozen_string_literal: true

require "test_helper"

class PlayerSearchTest < ActiveSupport::TestCase
  def setup
    @region = regions(:bbl)
    @club = clubs(:club_bochum)
    @season = seasons(:season_2024)
    
    @player = Player.create!(
      firstname: "Hans",
      lastname: "Meyer",
      nickname: "Hansi",
      cc_id: 12345,
      dbu_nr: 67890,
      region: @region
    )
    
    SeasonParticipation.create!(
      player: @player,
      club: @club,
      season: @season
    )
  end

  test "search_hash returns valid configuration" do
    hash = Player.search_hash({ sSearch: "test" })
    
    assert_equal Player, hash[:model]
    assert_includes hash.keys, :column_names
    assert_includes hash.keys, :raw_sql
    assert_includes hash.keys, :joins
    assert_includes hash.keys, :distinct
  end

  test "COLUMN_NAMES includes all required fields" do
    column_names = Player::COLUMN_NAMES
    
    # IDs
    assert_equal "players.id", column_names["id"]
    assert_equal "regions.id", column_names["region_id"]
    assert_equal "season_participations.club_id", column_names["club_id"]
    
    # Externe IDs
    assert_equal "players.cc_id", column_names["CC_ID"]
    assert_equal "players.dbu_nr", column_names["DBU_ID"]
    
    # Referenzen
    assert_equal "regions.shortname", column_names["Region"]
    assert_equal "clubs.shortname", column_names["Club"]
    
    # Eigene Felder
    assert_equal "players.firstname", column_names["Firstname"]
    assert_equal "players.lastname", column_names["Lastname"]
    assert_equal "players.nickname", column_names["Nickname"]
  end

  test "text_search_sql is defined" do
    sql = Player.text_search_sql
    
    assert_not_nil sql
    assert_includes sql, "players.firstname"
    assert_includes sql, "players.lastname"
    assert_includes sql, "players.nickname"
    assert_includes sql, "players.cc_id"
  end

  test "search_joins returns array" do
    joins = Player.search_joins
    
    assert_kind_of Array, joins
    assert_includes joins, :season_participations
    assert_includes joins, :region
  end

  test "search_distinct? returns true" do
    assert Player.search_distinct?
  end

  test "cascading_filters includes region to club" do
    filters = Player.cascading_filters
    
    assert_equal ['club_id'], filters['region_id']
  end

  test "filter_field_types detects correct types" do
    types = Player.filter_field_types
    
    # Hidden fields
    assert_equal :hidden, types["id"]
    assert_equal :hidden, types["region_id"]
    assert_equal :hidden, types["club_id"]
    
    # Numbers
    assert_equal :number, types["CC_ID"]
    assert_equal :number, types["DBU_ID"]
    
    # Selects
    assert_equal :select, types["Region"]
    assert_equal :select, types["Club"]
    
    # Text
    assert_equal :text, types["Firstname"]
    assert_equal :text, types["Lastname"]
    assert_equal :text, types["Nickname"]
  end

  test "field_examples returns descriptions" do
    examples = Player.field_examples("Firstname")
    
    assert_not_nil examples[:description]
    assert_kind_of Array, examples[:examples]
  end

  test "SearchService can use Player search_hash" do
    params = { sSearch: "Meyer", sort: "lastname", direction: "asc" }
    result = SearchService.call(Player.search_hash(params))
    
    assert_includes result, @player
  end

  test "filters by ID field" do
    params = { sSearch: "cc_id:#{@player.cc_id}" }
    result = SearchService.call(Player.search_hash(params))
    
    assert_includes result, @player
  end

  test "filters by text field" do
    params = { sSearch: "firstname:Hans" }
    result = SearchService.call(Player.search_hash(params))
    
    assert_includes result, @player
  end

  test "combines multiple filters" do
    params = { sSearch: "firstname:Hans lastname:Meyer" }
    result = SearchService.call(Player.search_hash(params))
    
    assert_includes result, @player
  end
end

