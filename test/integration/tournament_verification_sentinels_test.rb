# frozen_string_literal: true

require "test_helper"

# Regression guard for quick-260506-o93 Layer 4 fix:
# verify_tournament_start_parameters MUST exempt the form's sentinel values
# (sets_to_play = 0 "not set" / 999 "no limit"; sets_to_win = 0 "not set")
# from the UI_07_SHARED_RANGES range check. Without this guard, single-set
# tournaments — and ANY tournament whose operator hasn't yet picked a
# sets-config — trip the verification modal even when balls_goal / innings_goal
# are perfectly in range. Cross-references:
#   app/controllers/tournaments_controller.rb verify_tournament_start_parameters
#   app/views/tournaments/tournament_monitor.html.erb:139, 142 (form select options)
#   app/models/discipline.rb UI_07_SHARED_RANGES (the contested ranges)
#   .planning/quick/260506-me5-get-36b-06-system-tests-3-4-to-pass-via-/260506-me5-SUMMARY.md (Layer 4 discovery)
class TournamentVerificationSentinelsTest < ActionDispatch::IntegrationTest
  # Lightweight tournament double: only `discipline.parameter_ranges` is read by the
  # verifier (line 1012 of tournaments_controller.rb). We build a Struct-based pair
  # to avoid coupling this regression test to Discipline / Tournament fixture state.
  FakeDiscipline = Struct.new(:parameter_ranges)
  FakeTournament = Struct.new(:discipline)

  # The full UI_07 range set the verifier reads via tournament.discipline.parameter_ranges.
  # Mirrors UI_07_SHARED_RANGES (discipline.rb:60-65) plus a representative balls_goal
  # range for an arbitrary discipline so we can prove non-sentinel out-of-range still trips.
  RANGES = {
    balls_goal: 50..200,
    innings_goal: 5..200,
    timeout: 30..90,
    time_out_warm_up_first_min: 1..10,
    time_out_warm_up_follow_up_min: 0..5,
    sets_to_play: 1..7,
    sets_to_win: 1..4
  }.freeze

  def build_tournament
    FakeTournament.new(FakeDiscipline.new(RANGES))
  end

  def call_verifier(raw_params)
    controller = TournamentsController.new
    controller.send(:verify_tournament_start_parameters, build_tournament, raw_params)
  end

  test "sets_to_play=0 (form '-' / not set) is exempt from the 1..7 range check" do
    failures = call_verifier(
      balls_goal: "100", sets_to_play: "0", sets_to_win: "2"
    )
    refute(failures.any? { |f| f[:field] == :sets_to_play },
           "sets_to_play=0 must be exempt — it is the form's '-' / not-set sentinel")
    assert_empty failures, "no other field is out of range, so failures must be empty"
  end

  test "sets_to_play=999 (form 'no limit') is exempt from the 1..7 range check" do
    failures = call_verifier(
      balls_goal: "100", sets_to_play: "999", sets_to_win: "2"
    )
    refute(failures.any? { |f| f[:field] == :sets_to_play },
           "sets_to_play=999 must be exempt — it is the form's 'no limit' sentinel")
    assert_empty failures
  end

  test "sets_to_win=0 (form '-' / not set) is exempt from the 1..4 range check" do
    failures = call_verifier(
      balls_goal: "100", sets_to_play: "3", sets_to_win: "0"
    )
    refute(failures.any? { |f| f[:field] == :sets_to_win },
           "sets_to_win=0 must be exempt — it is the form's '-' / not-set sentinel")
    assert_empty failures
  end

  test "single-set tournament parameter set (Layer 4 reproducer) returns no failures" do
    # Exact shape of the form submission for a single-set in-range tournament,
    # mirroring tournament_parameter_verification_test.rb Test 4: balls_goal in
    # range, sets_to_play and sets_to_win both at the form's '-' sentinel (0).
    failures = call_verifier(
      balls_goal: "100", innings_goal: "", timeout: "45",
      time_out_warm_up_first_min: "5", time_out_warm_up_follow_up_min: "2",
      sets_to_play: "0", sets_to_win: "0"
    )
    assert_empty failures,
                 "Layer 4: single-set form submission must NOT trigger the modal"
  end

  test "out-of-range balls_goal still trips the verifier (sentinel guard does not over-exempt)" do
    # Negative regression: prove the sentinel exemption does not silently
    # neutralize the verifier for non-sentinel fields. balls_goal=99999 must
    # still be flagged even when sets_to_play / sets_to_win carry sentinels.
    failures = call_verifier(
      balls_goal: "99999", sets_to_play: "0", sets_to_win: "0"
    )
    assert(failures.any? { |f| f[:field] == :balls_goal && f[:value] == 99999 },
           "balls_goal=99999 must still be flagged; sentinel guard must not over-exempt")
  end

  test "sets_to_win=999 (NOT a form option) is still flagged" do
    # Defense-in-depth: the form does not offer 999 for sets_to_win — only for
    # sets_to_play. UI_07_SENTINEL_VALUES[:sets_to_win] is [0] only. A submitted
    # 999 for sets_to_win therefore IS a real out-of-range value and must trip.
    failures = call_verifier(
      balls_goal: "100", sets_to_play: "3", sets_to_win: "999"
    )
    assert(failures.any? { |f| f[:field] == :sets_to_win && f[:value] == 999 },
           "sets_to_win=999 is NOT a form option and must remain out-of-range")
  end
end
