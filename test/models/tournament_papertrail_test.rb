# frozen_string_literal: true

require "test_helper"

# Characterization tests for PaperTrail version tracking on Tournament.
#
# These baselines pin the exact version counts for every state-changing operation.
# Extraction phases 13-15 MUST preserve these counts unchanged.
#
# PaperTrail configuration (LocalProtector#has_paper_trail):
#   has_paper_trail(skip: lambda {...})
#   The skip lambda was designed to skip versions when only sync_date/updated_at changed,
#   but its lambda form does NOT prevent version creation — it's treated as a filter
#   on which fields to track, not as a should-record guard.
#
# AASM uses `update_all` (raw SQL) which bypasses ActiveRecord callbacks entirely,
# so AASM transitions produce 0 PaperTrail versions.
#
# PaperTrail is active in test environment (no carambus_api_url configured).
class TournamentPapertrailTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    # Sanity check: PaperTrail must be active in this test environment.
    # If this fails, version count assertions below are meaningless.
    assert PaperTrail.enabled?, "PaperTrail must be enabled — check LocalProtector configuration"

    # Create a fresh local tournament for each test to isolate version counts.
    @tournament = Tournament.create!(
      title: "PT Test Tournament",
      season: seasons(:current),
      organizer: regions(:nbv),
      organizer_type: "Region"
    )
    # Capture baseline version count. We do NOT assert exactly 1 here because
    # AASM after_enter callbacks (reset_tournament, calculate_and_cache_rankings)
    # may produce additional versions depending on fixture state and test ordering.
    # The dedicated "create! produces exactly 1 version" test pins the count
    # in isolation without setup-ordering interference.
    @initial_count = @tournament.versions.count
  end

  # Baseline: create! -> 1 version.
  # Extraction must preserve: Tournament.create! still increments PaperTrail::Version.count by 1.
  test "create! produces exactly 1 PaperTrail version" do
    assert_difference "PaperTrail::Version.count", 1 do
      Tournament.create!(
        title: "New Tournament",
        season: seasons(:current),
        organizer: regions(:nbv),
        organizer_type: "Region"
      )
    end
  end

  # Baseline: update!(title) -> 1 version.
  # The title change is substantive and produces exactly one version per save.
  test "update! with title change produces 1 version" do
    assert_difference "@tournament.versions.count", 1 do
      @tournament.update!(title: "Changed Title")
    end
  end

  # Baseline: update!(sync_date) -> 1 version.
  # The skip lambda in LocalProtector is defined as a lambda passed to the `skip:` option
  # of has_paper_trail. In PaperTrail, the `skip:` option accepts an array of attribute names
  # to exclude from version diffs — a lambda is accepted but does NOT prevent version creation.
  # Therefore sync_date-only updates still create a version (the lambda is not a guard).
  # This is the ACTUAL behavior of the production system — characterize it as-is.
  test "update! with only sync_date change produces 1 version (skip lambda does not prevent version creation)" do
    assert_difference "@tournament.versions.count", 1 do
      @tournament.update!(sync_date: Time.current)
    end
  end

  # Baseline: update_columns -> 0 versions.
  # update_columns bypasses ActiveRecord callbacks entirely — PaperTrail never fires.
  test "update_columns bypasses PaperTrail entirely (0 versions)" do
    assert_no_difference "@tournament.versions.count" do
      @tournament.update_columns(title: "Bypass")
    end
  end

  # Baseline: update! changing two substantive fields -> 1 version (not 2).
  # PaperTrail creates one version per save, regardless of how many fields changed.
  test "update! changing two substantive fields produces 1 version" do
    assert_difference "@tournament.versions.count", 1 do
      @tournament.update!(title: "New Title", shortname: "NT")
    end
  end

  # Baseline: AASM transitions -> 0 versions.
  # AASM with skip_validation_on_save:true uses UPDATE ... WHERE id = ? (via update_all),
  # which bypasses ActiveRecord save callbacks, so PaperTrail never fires.
  # Each transition below: 0 versions produced on the Tournament record.

  # Baseline: finish_seeding! (new_tournament -> tournament_seeding_finished) -> 0 versions.
  test "AASM transition finish_seeding! produces 0 versions" do
    @tournament.update_column(:state, "new_tournament")
    @tournament.reload
    assert_no_difference "@tournament.versions.count" do
      @tournament.finish_seeding!
    end
  end

  # Baseline: finish_mode_selection! (tournament_seeding_finished -> tournament_mode_defined) -> 0 versions.
  test "AASM transition finish_mode_selection! produces 0 versions" do
    @tournament.update_column(:state, "tournament_seeding_finished")
    @tournament.reload
    assert_no_difference "@tournament.versions.count" do
      @tournament.finish_mode_selection!
    end
  end

  # Baseline: finish_tournament! (tournament_started -> tournament_finished) -> 0 versions.
  test "AASM transition finish_tournament! produces 0 versions" do
    @tournament.update_column(:state, "tournament_started")
    @tournament.reload
    assert_no_difference "@tournament.versions.count" do
      @tournament.finish_tournament!
    end
  end

  # Baseline: have_results_published! (tournament_finished -> results_published) -> 0 versions.
  test "AASM transition have_results_published! produces 0 versions" do
    @tournament.update_column(:state, "tournament_finished")
    @tournament.reload
    assert_no_difference "@tournament.versions.count" do
      @tournament.have_results_published!
    end
  end

  # Baseline: reset_tournament (called directly as per code comment: "use direct only for testing purposes").
  # reset_tournament is the after_enter callback for new_tournament state.
  #
  # IMPORTANT DISCOVERY: The save inside reset_tournament is guarded by:
  #   unless new_record? || (id.present? && id > Seeding::MIN_ID)
  # In the test environment, newly created tournaments receive IDs >= 50_000_000 (MIN_ID)
  # because fixtures define records with id 50_000_001+, advancing the DB sequence.
  # Therefore the save branch is SKIPPED for all test-created local tournaments.
  #
  # Baseline: direct reset_tournament call -> 0 versions on a local tournament (id >= MIN_ID).
  # The save that would produce a version is bypassed — only global records (id < MIN_ID) get saved.
  #
  # Note: forced_reset_tournament_monitor! cannot be tested directly because:
  #   admin_can_reset_tournament? requires User.current or a blank PaperTrail whodunnit,
  #   but the before_save hook sets whodunnit to a proc, making it non-blank → guard fails.
  test "reset_tournament direct call produces 0 versions for local tournament (save branch skipped)" do
    @tournament.update_column(:state, "tournament_started")
    @tournament.reload
    before_count = @tournament.versions.count
    @tournament.reset_tournament
    after_count = @tournament.reload.versions.count
    # Baseline: reset_tournament on a local tournament (id >= MIN_ID) -> 0 versions.
    # The internal save is only for global records (id < MIN_ID). Local records skip the save.
    assert_equal 0, after_count - before_count,
      "Baseline: reset_tournament on local tournament -> 0 versions. " \
      "The save branch inside reset_tournament is skipped for id >= MIN_ID."
  end

  # Baseline: tournament_local dynamic setter -> 0 versions on Tournament.
  # The setter delegates to TournamentLocal (a separate record), NOT to Tournament.
  # This verifies the sync contract: dynamic attribute setters do not pollute Tournament versions.
  # Uses tournaments(:imported) (id: 1000, global) which exercises the tournament_local delegation path.
  test "tournament_local dynamic setter does not produce a Tournament version" do
    tournament = tournaments(:imported)
    before_count = tournament.versions.count
    # The timeout setter routes to tournament_local via method_missing delegation
    tournament.timeout = 99
    after_count = tournament.reload.versions.count
    assert_equal before_count, after_count,
      "Baseline: tournament_local setter -> 0 Tournament versions. " \
      "Dynamic attr setter must NOT produce a version on the Tournament record itself."
  end

  # Baseline: destroy! -> 1 version.
  # PaperTrail records a destroy event as a version with event: "destroy".
  test "destroy! produces 1 version" do
    t = Tournament.create!(
      title: "To Delete",
      season: seasons(:current),
      organizer: regions(:nbv),
      organizer_type: "Region"
    )
    assert_difference "PaperTrail::Version.count", 1 do
      t.destroy!
    end
  end
end
