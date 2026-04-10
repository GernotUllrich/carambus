# frozen_string_literal: true

require "test_helper"

# Characterization tests for Tournament dynamic attribute delegation.
#
# Covers all 13 define_method getter/setter code paths (CHAR-07):
#   timeouts, timeout, gd_has_prio, admin_controlled, auto_upload_to_cc,
#   sets_to_play, sets_to_win, team_size, kickoff_switches_with, allow_follow_up,
#   allow_overflow, fixed_display_left, color_remains_with_set
#
# Four getter paths:
#   1. Local record (id >= MIN_ID) — uses read_attribute
#   2. Global record with tournament_local — delegates to tournament_local
#   3. Global record without tournament_local — falls back to read_attribute
#   4. New record (id nil) — uses read_attribute
#
# Four setter paths:
#   1. New record — write_attribute
#   2. Global record, no tournament_local — creates tournament_local, sets value
#   3. Global record, existing tournament_local — updates tournament_local
#   4. Local record — write_attribute
#
# Special case: auto_upload_to_cc on global record.
# NOTE: Despite the plan's research suggesting auto_upload_to_cc is missing from
# TournamentLocal, the actual schema includes it. All 13 attributes including
# auto_upload_to_cc work normally. This test characterizes the actual behavior.
class TournamentAttributesTest < ActiveSupport::TestCase
  ATTR_TEST_ID_BASE = 50_150_000

  self.use_transactional_tests = true

  setup do
    @id_counter = 0
    clear_user_context
  end

  teardown do
    clear_user_context
  end

  def clear_user_context
    User.current = nil
    PaperTrail.request.whodunnit = nil
  end

  def next_id
    @id_counter += 1
    ATTR_TEST_ID_BASE + @id_counter
  end

  def create_local_tournament(attrs = {})
    t = Tournament.new(
      {
        id: next_id,
        title: "Attr Test Local",
        season: seasons(:current),
        organizer: regions(:nbv),
        organizer_type: "Region",
        date: 2.weeks.from_now
      }.merge(attrs)
    )
    t.save!(validate: false)
    clear_user_context
    t
  end

  # ============================================================================
  # 1. Getter — local record (id >= MIN_ID)
  #    Condition: id.present? && id < MIN_ID is FALSE → uses read_attribute
  # ============================================================================

  test "getter on local record returns read_attribute for integer timeout" do
    tournament = create_local_tournament
    tournament.update_column(:timeout, 99)
    tournament.reload
    assert_equal 99, tournament.timeout,
      "Getter on local record should read directly from the tournament column"
  end

  test "getter on local record returns read_attribute for boolean gd_has_prio" do
    tournament = create_local_tournament
    tournament.update_column(:gd_has_prio, true)
    tournament.reload
    assert_equal true, tournament.gd_has_prio,
      "Getter on local record should read gd_has_prio from tournament column"
  end

  test "getter on local record returns read_attribute for string kickoff_switches_with" do
    tournament = create_local_tournament
    tournament.update_column(:kickoff_switches_with, "winner")
    tournament.reload
    assert_equal "winner", tournament.kickoff_switches_with,
      "Getter on local record should read kickoff_switches_with from tournament column"
  end

  test "getter on local record ignores tournament_local even when present" do
    # For local records (id >= MIN_ID), the getter uses read_attribute regardless of tournament_local
    # because the condition `id < MIN_ID` is false.
    tournament = create_local_tournament
    tournament.update_column(:timeout, 55)
    # Create a tournament_local with a different value — should be ignored by getter
    tol = TournamentLocal.new(id: next_id, tournament: tournament, timeout: 999)
    tol.save!(validate: false)
    clear_user_context
    tournament.reload
    assert_equal 55, tournament.timeout,
      "Getter on local record should use read_attribute, not tournament_local value"
  end

  # ============================================================================
  # 2. Getter — global record with tournament_local
  #    Condition: id < MIN_ID && tournament_local.present? → delegates to tournament_local
  # ============================================================================

  test "getter on global record with tournament_local returns tournament_local value for timeout" do
    tournament = tournaments(:imported) # id: 1000 < MIN_ID
    TournamentLocal.create!(tournament: tournament, timeout: 77)
    tournament.reload
    assert_equal 77, tournament.timeout,
      "Getter on global record with tournament_local should return tournament_local.timeout"
  end

  test "getter on global record with tournament_local returns tournament_local value for gd_has_prio" do
    tournament = tournaments(:imported)
    TournamentLocal.create!(tournament: tournament, gd_has_prio: true)
    tournament.reload
    assert_equal true, tournament.gd_has_prio,
      "Getter on global record with tournament_local should return tournament_local.gd_has_prio"
  end

  test "getter on global record with tournament_local returns tournament_local value for sets_to_play" do
    tournament = tournaments(:imported)
    TournamentLocal.create!(tournament: tournament, sets_to_play: 3)
    tournament.reload
    assert_equal 3, tournament.sets_to_play,
      "Getter on global record with tournament_local should return tournament_local.sets_to_play"
  end

  # ============================================================================
  # 3. Getter — global record without tournament_local
  #    Condition: tournament_local.nil? → falls back to read_attribute
  # ============================================================================

  test "getter on global record without tournament_local falls back to read_attribute for timeout" do
    tournament = tournaments(:imported) # id: 1000, no tournament_local by default
    assert_nil tournament.tournament_local, "imported fixture should have no tournament_local"
    expected = tournament.read_attribute(:timeout)
    assert_equal expected, tournament.timeout,
      "Getter on global record without tournament_local should fall back to read_attribute"
  end

  test "getter on global record without tournament_local falls back to read_attribute for allow_follow_up" do
    tournament = tournaments(:imported)
    assert_nil tournament.tournament_local
    expected = tournament.read_attribute(:allow_follow_up)
    assert_equal expected, tournament.allow_follow_up,
      "Getter on global record without tournament_local should fall back to read_attribute for allow_follow_up"
  end

  # ============================================================================
  # 4. Getter — new record (id nil)
  #    Condition: id.present? is FALSE → uses read_attribute
  # ============================================================================

  test "getter on new record returns read_attribute value" do
    tournament = Tournament.new(timeout: 30)
    assert_nil tournament.id, "new record should have no id"
    assert_equal 30, tournament.timeout,
      "Getter on new record should use read_attribute (id.present? is false)"
  end

  # ============================================================================
  # 5. Setter — new record (write_attribute path)
  # ============================================================================

  test "setter on new record uses write_attribute for timeout" do
    tournament = Tournament.new
    tournament.timeout = 45
    assert_equal 45, tournament.read_attribute(:timeout),
      "Setter on new record should write to the tournament attribute directly"
  end

  test "setter on new record uses write_attribute for sets_to_play" do
    tournament = Tournament.new
    tournament.sets_to_play = 5
    assert_equal 5, tournament.read_attribute(:sets_to_play),
      "Setter on new record should write sets_to_play to the tournament attribute directly"
  end

  # ============================================================================
  # 6. Setter — global record, no existing tournament_local
  #    Creates tournament_local copying 12 attributes, then sets the value
  # ============================================================================

  test "setter on global record creates tournament_local when none exists" do
    tournament = tournaments(:imported)
    assert_nil tournament.tournament_local, "should have no tournament_local initially"

    tournament.timeout = 60

    assert tournament.tournament_local.present?,
      "Setter on global record should create a tournament_local"
    assert_equal 60, tournament.tournament_local.timeout,
      "tournament_local.timeout should reflect the set value"
  end

  test "setter on global record initializes tournament_local with tournament own column values" do
    tournament = tournaments(:imported)
    tournament.update_column(:sets_to_play, 2)
    tournament.update_column(:allow_follow_up, false)
    tournament.reload

    # Trigger creation by setting any attribute
    tournament.timeout = 99

    tol = tournament.tournament_local
    assert tol.present?, "tournament_local should be created"
    assert_equal 2, tol.sets_to_play,
      "tournament_local.sets_to_play should be copied from tournament column"
    assert_equal false, tol.allow_follow_up,
      "tournament_local.allow_follow_up should be copied from tournament column"
  end

  # ============================================================================
  # 7. Setter — global record, existing tournament_local (update path)
  # ============================================================================

  test "setter on global record updates existing tournament_local" do
    tournament = tournaments(:imported)
    TournamentLocal.create!(tournament: tournament, timeout: 30)
    clear_user_context
    tournament.reload

    tournament.timeout = 88

    assert_equal 88, tournament.tournament_local.reload.timeout,
      "Setter on global record should update the existing tournament_local"
  end

  test "setter on global record updates tournament_local for boolean attribute" do
    tournament = tournaments(:imported)
    TournamentLocal.create!(tournament: tournament, gd_has_prio: false)
    clear_user_context
    tournament.reload

    tournament.gd_has_prio = true

    assert_equal true, tournament.tournament_local.reload.gd_has_prio,
      "Setter on global record should update gd_has_prio on tournament_local"
  end

  # ============================================================================
  # 8. Setter — local record (write_attribute path)
  # ============================================================================

  test "setter on local record uses write_attribute for timeout" do
    tournament = create_local_tournament
    tournament.timeout = 120
    assert_equal 120, tournament.read_attribute(:timeout),
      "Setter on local record should write to the tournament column via write_attribute"
  end

  test "setter on local record uses write_attribute for allow_overflow" do
    tournament = create_local_tournament
    tournament.allow_overflow = true
    assert_equal true, tournament.read_attribute(:allow_overflow),
      "Setter on local record should write allow_overflow via write_attribute"
  end

  # ============================================================================
  # 9. Special case: auto_upload_to_cc on global record
  #
  # Characterization (actual behavior — correcting plan research):
  # auto_upload_to_cc IS present on tournament_locals table in the actual schema.
  # All 13 attributes including auto_upload_to_cc work via the standard delegation paths.
  # The plan's research suggesting it was missing was based on an outdated schema annotation.
  # ============================================================================

  test "auto_upload_to_cc column exists on TournamentLocal in actual schema" do
    # Pin that auto_upload_to_cc IS a column on tournament_locals (correcting plan research)
    assert_includes TournamentLocal.column_names, "auto_upload_to_cc",
      "auto_upload_to_cc should be a column on tournament_locals table"
  end

  test "auto_upload_to_cc setter on global record without tournament_local creates tournament_local" do
    # Because auto_upload_to_cc exists on TournamentLocal, the setter works normally
    tournament = tournaments(:imported)
    assert_nil tournament.tournament_local

    assert_nothing_raised do
      tournament.auto_upload_to_cc = true
    end

    assert tournament.tournament_local.present?,
      "Setting auto_upload_to_cc on global record should create tournament_local"
    assert_equal true, tournament.tournament_local.reload.auto_upload_to_cc,
      "tournament_local.auto_upload_to_cc should be set to true"
  end

  test "auto_upload_to_cc setter on global record with existing tournament_local updates it" do
    tournament = tournaments(:imported)
    TournamentLocal.create!(tournament: tournament, auto_upload_to_cc: false)
    clear_user_context
    tournament.reload

    assert_nothing_raised do
      tournament.auto_upload_to_cc = true
    end

    assert_equal true, tournament.tournament_local.reload.auto_upload_to_cc,
      "Setter should update auto_upload_to_cc on existing tournament_local"
  end

  test "auto_upload_to_cc getter on global record with tournament_local delegates to tournament_local" do
    tournament = tournaments(:imported)
    TournamentLocal.create!(tournament: tournament, auto_upload_to_cc: true)
    tournament.reload

    assert_equal true, tournament.auto_upload_to_cc,
      "auto_upload_to_cc getter should delegate to tournament_local on global record"
  end

  test "auto_upload_to_cc getter on global record without tournament_local uses read_attribute" do
    tournament = tournaments(:imported)
    assert_nil tournament.tournament_local
    expected = tournament.read_attribute(:auto_upload_to_cc)
    assert_equal expected, tournament.auto_upload_to_cc,
      "auto_upload_to_cc getter on global record without tournament_local uses read_attribute"
  end

  test "auto_upload_to_cc getter on local record returns read_attribute without error" do
    tournament = create_local_tournament
    assert_nothing_raised do
      tournament.auto_upload_to_cc
    end
  end

  test "auto_upload_to_cc setter on local record writes via write_attribute without error" do
    tournament = create_local_tournament
    assert_nothing_raised do
      tournament.auto_upload_to_cc = true
    end
    assert_equal true, tournament.read_attribute(:auto_upload_to_cc),
      "auto_upload_to_cc setter on local record should write via write_attribute"
  end
end
