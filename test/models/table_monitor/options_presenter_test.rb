# frozen_string_literal: true

require "test_helper"

# Unit tests for TableMonitor::OptionsPresenter.
#
# Strategy: Build minimal real AR records (TableMonitor, Game, Player,
# GameParticipation) and stub complex associations (table, location).
# This avoids the full Table -> Location -> TableKind graph while still
# exercising the presenter logic on real model instances.
class TableMonitor::OptionsPresenterTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Setup / Teardown
  # ---------------------------------------------------------------------------

  setup do
    # Reset cattr_accessors to prevent state leaks between tests (Pitfall 2)
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
  end

  teardown do
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def minimal_data(overrides = {})
    {
      "free_game_form" => nil,
      "first_break_choice" => nil,
      "balls_on_table" => 15,
      "balls_counter" => 0,
      "extra_balls" => 0,
      "warntime" => nil,
      "gametime" => nil,
      "team_size" => nil,
      "redo_sets" => nil,
      "innings_goal" => nil,
      "timeout" => nil,
      "timeouts" => nil,
      "ba_results" => nil,
      "current_kickoff_player" => nil,
      "current_left_player" => nil,
      "current_left_color" => nil,
      "sets_to_play" => nil,
      "sets_to_win" => nil,
      "kickoff_switches_with" => nil,
      "color_remains_with_set" => nil,
      "allow_overflow" => nil,
      "allow_follow_up" => nil,
      "balls_counter_stack" => nil,
      "fixed_display_left" => nil,
      "current_inning" => { "active_player" => nil, "balls" => 0 },
      "playera" => { "result" => 5, "hs" => 3, "gd" => 1.5, "innings" => 2, "tc" => 0, "fouls_1" => 0, "discipline" => "Freie Partie", "balls_goal" => "15" },
      "playerb" => { "result" => 3, "hs" => 2, "gd" => 1.0, "innings" => 2, "tc" => 0, "fouls_1" => 1, "discipline" => "Freie Partie", "balls_goal" => "15" }
    }.merge(overrides)
  end

  # Creates a real TableMonitor with a game and two players.
  # Stubs the `table` association so we don't need Table/Location/TableKind records.
  def build_tm_with_game(player_a_attrs: {}, player_b_attrs: {}, data_overrides: {})
    player_a = Player.create!(
      firstname: player_a_attrs.fetch(:firstname, "Max"),
      lastname: player_a_attrs.fetch(:lastname, "Muster"),
      fl_name: "#{player_a_attrs.fetch(:firstname, 'Max')} #{player_a_attrs.fetch(:lastname, 'Muster')}",
      guest: player_a_attrs.fetch(:guest, false),
      id: 50_000_000 + rand(1_000_000)
    )
    player_b = Player.create!(
      firstname: player_b_attrs.fetch(:firstname, "Erika"),
      lastname: player_b_attrs.fetch(:lastname, "Beispiel"),
      fl_name: "#{player_b_attrs.fetch(:firstname, 'Erika')} #{player_b_attrs.fetch(:lastname, 'Beispiel')}",
      guest: player_b_attrs.fetch(:guest, false),
      id: 50_000_000 + rand(1_000_000)
    )

    game = Game.create!(
      data: minimal_data(data_overrides),
      gname: "presenter_test_#{SecureRandom.hex(4)}"
    )
    GameParticipation.create!(game: game, player: player_a, role: "playera")
    GameParticipation.create!(game: game, player: player_b, role: "playerb")

    tm = TableMonitor.create!(
      state: "playing",
      data: minimal_data(data_overrides),
      game: game
    )

    # Stub table association (avoids Table/Location/TableKind setup)
    mock_location = OpenStruct.new(id: 1, name: "Test Location")
    mock_table = OpenStruct.new(location: mock_location)
    tm.define_singleton_method(:table) { mock_table }

    [tm, player_a, player_b, game]
  end

  # ---------------------------------------------------------------------------
  # Test 1: call returns a Hash
  # ---------------------------------------------------------------------------

  test "call returns a HashWithIndifferentAccess (or Hash)" do
    tm, _, _, _ = build_tm_with_game
    presenter = TableMonitor::OptionsPresenter.new(tm, locale: :de)
    result = presenter.call
    assert result.is_a?(Hash), "Expected Hash, got #{result.class}"
  end

  # ---------------------------------------------------------------------------
  # Test 2: Returned hash contains required top-level keys
  # ---------------------------------------------------------------------------

  test "returned hash contains required top-level keys" do
    tm, _, _, _ = build_tm_with_game
    presenter = TableMonitor::OptionsPresenter.new(tm, locale: :de)
    result = presenter.call

    %w[id name game_name tournament_title player_a player_b current_inning].each do |key|
      assert result.key?(key), "Expected result to contain key '#{key}'"
    end
  end

  # ---------------------------------------------------------------------------
  # Test 3: player_a and player_b nested hashes contain required keys
  # ---------------------------------------------------------------------------

  test "player_a and player_b nested hashes contain required keys" do
    tm, _, _, _ = build_tm_with_game
    presenter = TableMonitor::OptionsPresenter.new(tm, locale: :de)
    result = presenter.call

    %w[lastname firstname fullname balls_goal result hs gd innings discipline tc fouls_1 logo].each do |key|
      assert result["player_a"].key?(key), "Expected player_a to contain key '#{key}'"
      assert result["player_b"].key?(key), "Expected player_b to contain key '#{key}'"
    end
  end

  # ---------------------------------------------------------------------------
  # Test 4: When showing_prev_game (game.blank?), uses prev_game and prev_data
  # ---------------------------------------------------------------------------

  test "when game is blank, shows_prev_game is true and uses prev_data" do
    prev_game = Game.create!(
      data: minimal_data,
      gname: "prev_game_#{SecureRandom.hex(4)}"
    )

    tm = TableMonitor.create!(
      state: "ready",
      data: minimal_data,
      prev_data: minimal_data("balls_on_table" => 7),
      prev_game: prev_game
    )

    mock_location = OpenStruct.new(id: 1, name: "Test Location")
    mock_table = OpenStruct.new(location: mock_location)
    tm.define_singleton_method(:table) { mock_table }

    presenter = TableMonitor::OptionsPresenter.new(tm, locale: :de)
    result = presenter.call

    assert_equal true, result["showing_prev_game"]
    assert_equal 7, result["balls_on_table"]
  end

  # ---------------------------------------------------------------------------
  # Test 5: Player name disambiguation — shared firstname, different lastnames
  # ---------------------------------------------------------------------------

  test "disambiguation shortens fullnames when players share simple_firstname and have different lastnames" do
    tm, _, _, _ = build_tm_with_game(
      player_a_attrs: { firstname: "Andreas", lastname: "Meissner" },
      player_b_attrs: { firstname: "Andreas", lastname: "Mertens" }
    )

    presenter = TableMonitor::OptionsPresenter.new(tm, locale: :de)
    result = presenter.call

    fn_a = result["player_a"]["fullname"]
    fn_b = result["player_b"]["fullname"]

    # Both should be shortened to distinguishing prefix
    assert_match(/\AMei/, fn_a.split.last, "Expected player_a fullname to start with 'Mei', got #{fn_a}")
    assert_match(/\AMer/, fn_b.split.last, "Expected player_b fullname to start with 'Mer', got #{fn_b}")
  end

  # ---------------------------------------------------------------------------
  # Test 6: presenter.gps returns the game_participations array after call
  # ---------------------------------------------------------------------------

  test "gps reader returns game_participations array after call" do
    tm, player_a, player_b, game = build_tm_with_game
    presenter = TableMonitor::OptionsPresenter.new(tm, locale: :de)
    presenter.call

    assert_not_nil presenter.gps
    assert_equal 2, presenter.gps.size
    assert_equal "playera", presenter.gps[0].role
    assert_equal "playerb", presenter.gps[1].role
  end

  # ---------------------------------------------------------------------------
  # Test 7: presenter.show_tournament returns tournament or party
  # ---------------------------------------------------------------------------

  test "show_tournament returns nil when no tournament_monitor present" do
    tm, _, _, _ = build_tm_with_game
    presenter = TableMonitor::OptionsPresenter.new(tm, locale: :de)
    presenter.call

    # No tournament_monitor set — show_tournament should be nil
    assert_nil presenter.show_tournament
  end

  # ---------------------------------------------------------------------------
  # Test 8: presenter.location returns table.location
  # ---------------------------------------------------------------------------

  test "location reader returns table.location after call" do
    tm, _, _, _ = build_tm_with_game
    presenter = TableMonitor::OptionsPresenter.new(tm, locale: :de)
    presenter.call

    assert_not_nil presenter.location
    assert_equal "Test Location", presenter.location.name
  end

  # ---------------------------------------------------------------------------
  # Test 9: presenter.my_table returns the table
  # ---------------------------------------------------------------------------

  test "my_table reader returns the table after call" do
    tm, _, _, _ = build_tm_with_game
    presenter = TableMonitor::OptionsPresenter.new(tm, locale: :de)
    presenter.call

    assert_not_nil presenter.my_table
    assert_equal "Test Location", presenter.my_table.location.name
  end

  # ---------------------------------------------------------------------------
  # Test: No cattr assignments inside OptionsPresenter (class-level state unchanged)
  # ---------------------------------------------------------------------------

  test "call does not mutate TableMonitor cattr_accessors" do
    tm, _, _, _ = build_tm_with_game
    TableMonitor.gps = :sentinel

    presenter = TableMonitor::OptionsPresenter.new(tm, locale: :de)
    presenter.call

    # cattr_accessors should remain unchanged — only the wrapper sets them
    assert_equal :sentinel, TableMonitor.gps,
      "OptionsPresenter should not mutate TableMonitor.gps (wrapper responsibility)"
  end

  # ---------------------------------------------------------------------------
  # Test: No disambiguation when tournament_monitor present
  # ---------------------------------------------------------------------------

  test "disambiguation does not fire when tournament_monitor is present" do
    tm, _, _, _ = build_tm_with_game(
      player_a_attrs: { firstname: "Andreas", lastname: "Meissner" },
      player_b_attrs: { firstname: "Andreas", lastname: "Mertens" }
    )

    # Stub tournament_monitor to return a non-blank object (simulates PartyMonitor being set).
    # This avoids complex PartyMonitor + update_columns DB setup.
    mock_party_monitor = OpenStruct.new(id: 99_999_999, blank?: false, present?: true, is_a?: false, party: nil, tournament: nil, current_round: nil)
    mock_party_monitor.define_singleton_method(:is_a?) { |klass| klass == PartyMonitor }
    mock_party_monitor.define_singleton_method(:blank?) { false }
    tm.define_singleton_method(:tournament_monitor) { mock_party_monitor }

    presenter = TableMonitor::OptionsPresenter.new(tm, locale: :de)
    result = presenter.call

    # With tournament_monitor present, disambiguation block is skipped.
    fn_a = result["player_a"]["fullname"]
    fn_b = result["player_b"]["fullname"]

    # Should NOT be the shortened form (ends with ".")
    refute_match(/Mei\.\z/, fn_a, "Expected no disambiguation when tournament_monitor is set, got: #{fn_a}")
    refute_match(/Mer\.\z/, fn_b, "Expected no disambiguation when tournament_monitor is set, got: #{fn_b}")
  end
end
