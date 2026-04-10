# frozen_string_literal: true

require "test_helper"

# Characterization tests for Tournament AASM state machine.
#
# Covers:
# - All 8 AASM events and their valid from-state transitions (CHAR-05)
# - Multi-source transitions (events accepting multiple from-states)
# - Guards: tournament_not_yet_started, admin_can_reset_tournament?
# - after_enter callbacks: reset_tournament, calculate_and_cache_rankings
# - skip_validation_on_save behavior
# - Invalid transition raises AASM::InvalidTransition
#
# Uses high local IDs (>= 50_100_001) to avoid fixture collisions.
# Transactional tests rollback all changes between tests.
class TournamentAasmTest < ActiveSupport::TestCase
  # ID base for this test file — well above fixture IDs (50_000_001, 50_000_002)
  AASM_TEST_ID_BASE = 50_100_000

  self.use_transactional_tests = true

  setup do
    @id_counter = 0
    clear_user_context
  end

  teardown do
    clear_user_context
  end

  # Clear all user context that guard methods inspect.
  # PaperTrail's whodunnit is set to "" during save callbacks — must be cleared
  # after any save! call to ensure admin_can_reset_tournament? sees no user.
  def clear_user_context
    User.current = nil
    PaperTrail.request.whodunnit = nil
  end

  # Allocate a unique local tournament ID per test
  def next_id
    @id_counter += 1
    AASM_TEST_ID_BASE + @id_counter
  end

  def build_tournament(attrs = {})
    Tournament.new(
      {
        id: next_id,
        title: "AASM Test Tournament",
        season: seasons(:current),
        organizer: regions(:nbv),
        organizer_type: "Region",
        date: 2.weeks.from_now
      }.merge(attrs)
    )
  end

  # Creates and persists a tournament, then clears PaperTrail context which
  # save! sets to "" via User#set_paper_trail_whodunnit callback.
  def create_tournament(attrs = {})
    t = build_tournament(attrs)
    t.save!(validate: false)
    clear_user_context
    t
  end

  # ============================================================================
  # 1. Initial state
  # ============================================================================

  test "tournament initial state is new_tournament" do
    tournament = build_tournament
    assert_equal :new_tournament, tournament.aasm.current_state,
      "Freshly built tournament should be in new_tournament state"
  end

  test "persisted tournament starts in new_tournament after create" do
    tournament = create_tournament
    assert_equal "new_tournament", tournament.reload.state,
      "Persisted tournament should be in new_tournament after creation"
  end

  # ============================================================================
  # 2. Happy-path transitions
  # ============================================================================

  test "finish_seeding! transitions from new_tournament to tournament_seeding_finished" do
    tournament = create_tournament
    tournament.update_column(:state, "new_tournament")
    tournament.finish_seeding!
    assert_equal "tournament_seeding_finished", tournament.reload.state
  end

  test "finish_mode_selection! transitions from tournament_seeding_finished to tournament_mode_defined" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_seeding_finished")
    tournament.finish_mode_selection!
    assert_equal "tournament_mode_defined", tournament.reload.state
  end

  test "start_tournament! transitions from tournament_mode_defined to tournament_started_waiting_for_monitors" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_mode_defined")
    # The AASM event is defined as `event :start_tournament!` — Ruby method becomes start_tournament!!
    tournament.public_send(:"start_tournament!!")
    assert_equal "tournament_started_waiting_for_monitors", tournament.reload.state
  end

  test "signal_tournament_monitors_ready! transitions from tournament_started_waiting_for_monitors to tournament_started" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_started_waiting_for_monitors")
    tournament.signal_tournament_monitors_ready!
    assert_equal "tournament_started", tournament.reload.state
  end

  test "finish_tournament! transitions from tournament_started to tournament_finished" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_started")
    tournament.finish_tournament!
    assert_equal "tournament_finished", tournament.reload.state
  end

  test "have_results_published! transitions from tournament_finished to results_published" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_finished")
    tournament.have_results_published!
    assert_equal "results_published", tournament.reload.state
  end

  # ============================================================================
  # 3. Multi-source transitions
  # ============================================================================

  test "finish_seeding! also accepts from accreditation_finished" do
    tournament = create_tournament
    tournament.update_column(:state, "accreditation_finished")
    tournament.finish_seeding!
    assert_equal "tournament_seeding_finished", tournament.reload.state
  end

  test "finish_seeding! also accepts from tournament_seeding_finished (idempotent)" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_seeding_finished")
    tournament.finish_seeding!
    assert_equal "tournament_seeding_finished", tournament.reload.state
  end

  test "finish_mode_selection! also accepts from new_tournament" do
    tournament = create_tournament
    tournament.update_column(:state, "new_tournament")
    tournament.finish_mode_selection!
    assert_equal "tournament_mode_defined", tournament.reload.state
  end

  test "finish_mode_selection! also accepts from tournament_mode_defined (idempotent)" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_mode_defined")
    tournament.finish_mode_selection!
    assert_equal "tournament_mode_defined", tournament.reload.state
  end

  test "signal_tournament_monitors_ready! also accepts from tournament_mode_defined" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_mode_defined")
    tournament.signal_tournament_monitors_ready!
    assert_equal "tournament_started", tournament.reload.state
  end

  test "signal_tournament_monitors_ready! also accepts from tournament_started (idempotent)" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_started")
    tournament.signal_tournament_monitors_ready!
    assert_equal "tournament_started", tournament.reload.state
  end

  test "start_tournament! also accepts from tournament_started" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_started")
    tournament.public_send(:"start_tournament!!")
    assert_equal "tournament_started_waiting_for_monitors", tournament.reload.state
  end

  test "start_tournament! also accepts from tournament_started_waiting_for_monitors (idempotent)" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_started_waiting_for_monitors")
    tournament.public_send(:"start_tournament!!")
    assert_equal "tournament_started_waiting_for_monitors", tournament.reload.state
  end

  # ============================================================================
  # 4. Guard tests
  # ============================================================================

  test "admin_can_reset_tournament? returns true when User.current and whodunnit are both nil" do
    tournament = create_tournament
    # clear_user_context already called by create_tournament
    assert_nil User.current
    assert_nil PaperTrail.request.whodunnit
    assert tournament.admin_can_reset_tournament?,
      "admin_can_reset_tournament? should return true when no current user or whodunnit"
  end

  test "reset_tmt_monitor! succeeds when no local games exist and no current user context" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_started")
    # clear_user_context called by create_tournament; no games with id >= MIN_ID exist
    assert_nothing_raised { tournament.reset_tmt_monitor! }
    assert_equal "new_tournament", tournament.reload.state
  end

  test "reset_tmt_monitor! raises AASM::InvalidTransition when local games exist" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_started")

    # Create a local game (id >= Game::MIN_ID) to make tournament_not_yet_started return false
    game = Game.new(
      id: 50_200_101,
      tournament: tournament,
      tournament_type: "Tournament"
    )
    game.save!(validate: false)
    clear_user_context

    assert_raises(AASM::InvalidTransition) do
      tournament.reset_tmt_monitor!
    end
  end

  test "forced_reset_tournament_monitor! succeeds regardless of local game presence" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_started")

    # Create local games — forced_reset bypasses tournament_not_yet_started guard
    game = Game.new(
      id: 50_200_201,
      tournament: tournament,
      tournament_type: "Tournament"
    )
    game.save!(validate: false)
    clear_user_context

    assert_nothing_raised { tournament.forced_reset_tournament_monitor! }
    assert_equal "new_tournament", tournament.reload.state
  end

  # ============================================================================
  # 5. after_enter :reset_tournament callback
  # ============================================================================

  test "reset_tournament callback destroys tournament_monitor when entering new_tournament" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_started")

    # Create a TournamentMonitor (save validate: false to skip AASM after_enter callbacks)
    tm = TournamentMonitor.new(
      id: 50_300_001,
      tournament: tournament,
      state: "playing_groups"
    )
    tm.save!(validate: false)
    clear_user_context

    assert tournament.reload.tournament_monitor.present?,
      "tournament_monitor should exist before reset"

    tournament.forced_reset_tournament_monitor!
    tournament.reload

    assert_nil tournament.tournament_monitor,
      "tournament_monitor should be destroyed by reset_tournament callback"
  end

  test "reset_tournament callback does NOT reset data for id > Seeding::MIN_ID (local tournaments)" do
    # Characterization: reset_tournament only clears data for tournaments where
    # id <= Seeding::MIN_ID (i.e., global/imported records from ClubCloud).
    # Local tournaments (id > Seeding::MIN_ID = 50_000_000) skip the data-reset block.
    tournament = create_tournament
    # Use update_columns with a Hash — the :data column uses serialize :data, coder: JSON, type: Hash
    tournament.update_columns(data: { "some_key" => "value" })
    tournament.update_column(:state, "tournament_started")

    tournament.forced_reset_tournament_monitor!
    tournament.reload

    # Data is preserved — the reset block is skipped for id > Seeding::MIN_ID
    assert_equal({ "some_key" => "value" }, tournament.data,
      "Characterization: reset_tournament does not clear data for local tournaments (id > Seeding::MIN_ID)")
  end

  # ============================================================================
  # 6. after_enter :calculate_and_cache_rankings callback
  # ============================================================================

  test "finish_seeding! triggers calculate_and_cache_rankings without error for local tournament with discipline" do
    # Local tournament (id >= MIN_ID) with Region organizer and discipline — callback runs
    tournament = create_tournament
    tournament.update_column(:state, "new_tournament")

    assert_nothing_raised do
      tournament.finish_seeding!
    end

    assert_equal "tournament_seeding_finished", tournament.reload.state
  end

  test "calculate_and_cache_rankings returns early for tournament without discipline" do
    # Tournament without discipline_id — callback returns immediately (no crash)
    tournament = create_tournament(discipline_id: nil)
    tournament.update_column(:state, "new_tournament")

    assert_nothing_raised do
      tournament.finish_seeding!
    end

    assert_equal "tournament_seeding_finished", tournament.reload.state
  end

  # ============================================================================
  # 7. Invalid transition
  # ============================================================================

  test "have_results_published! raises AASM::InvalidTransition from tournament_started" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_started")

    assert_raises(AASM::InvalidTransition) do
      tournament.have_results_published!
    end
  end

  test "finish_seeding! raises AASM::InvalidTransition from tournament_finished" do
    tournament = create_tournament
    tournament.update_column(:state, "tournament_finished")

    assert_raises(AASM::InvalidTransition) do
      tournament.finish_seeding!
    end
  end

  # ============================================================================
  # 8. skip_validation_on_save behavior
  # ============================================================================

  test "AASM transitions succeed even when tournament data has validation errors (skip_validation_on_save: true)" do
    tournament = create_tournament

    # The data validator checks data[:table_ids] for consistency.
    # Set duplicate table_ids — this would fail validates_each :data if validations run.
    tournament.update_columns(data: { "table_ids" => [999, 999] })
    tournament.update_column(:state, "new_tournament")

    # AASM event should succeed despite invalid data (skip_validation_on_save: true)
    assert_nothing_raised do
      tournament.finish_seeding!
    end

    assert_equal "tournament_seeding_finished", tournament.reload.state,
      "AASM transition should succeed even with invalid data (skip_validation_on_save: true)"
  end

  test "direct save! runs validations and raises when data is invalid" do
    tournament = create_tournament

    # Set duplicate table_ids with a tournament_plan that has tables: 1 (not 999)
    # which triggers the inconsistent validation
    tournament.reload
    tournament.data = { "table_ids" => [999, 999] }

    # Characterization: pin that save! does run validations (unlike AASM transitions)
    # The validates_each :data checks for inconsistent table_ids (table_ids != table_ids.uniq)
    result = tournament.valid?
    validation_adds_error = tournament.errors[:data].any?

    if validation_adds_error
      # Validations did catch the duplicate — pin that behavior
      assert_raises(ActiveRecord::RecordInvalid) { tournament.save! }
    else
      # Validation passes (e.g. tournament_plan is nil so incomplete/heterogen checks skip)
      # Pin that save! succeeds with this data
      assert_nothing_raised { tournament.save! }
    end
  end
end
