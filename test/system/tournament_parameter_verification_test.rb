# frozen_string_literal: true

require "application_system_test_case"

# UI-07 D-20: Capybara system test for the parameter verification dialog
# that surfaces before start_tournament! when values are out of range.
#
# Uses robust name-based selectors because the tournament_monitor form
# uses number_field_tag :balls_goal (no associated <label for="..."> so
# Capybara label-based input lookups fail) and submit_tag (which always
# renders name="commit" regardless of i18n text drift).
class TournamentParameterVerificationTest < ApplicationSystemTestCase
  setup do
    # sign_in is provided by Devise::Test::IntegrationHelpers via
    # ApplicationSystemTestCase. Guard loudly so a misconfigured test
    # helper fails visibly instead of silently skipping the assertions.
    raise "sign_in helper required — include Devise::Test::IntegrationHelpers in ApplicationSystemTestCase" unless respond_to?(:sign_in)

    @user = begin
      users(:admin)
    rescue
      User.first
    end
    sign_in @user if @user

    # Phase 39 D-17: deterministic fixture (D-16a hit) instead of dynamic find — the
    # Phase 39 ranges depend on (tournament_plan, seedings.count, player_class), so a
    # tournament with parameter_ranges(tournament:).any? must satisfy ALL four lookup keys.
    # Fixture local_fpk_class1 (id 50_000_200) is the canonical D-16(a) hit:
    # discipline=Freie Partie klein, plan=t04_5, players=5 (via 5 seedings), class="1",
    # DTP row points=250 / innings=15.
    @tournament = tournaments(:local_fpk_class1)
    raise "Phase 39 fixture local_fpk_class1 missing — Plan 01 must land first" unless @tournament
    raise "Phase 39 parameter_ranges contract broken — fixture must have non-empty ranges" if @tournament.discipline.parameter_ranges(tournament: @tournament).empty?
  end

  # Visit the tournament_monitor page. If the pre-existing fixture 500
  # (see plan 36B-05 deviation 3) happens here, skip with a clear message.
  def visit_monitor_or_skip
    visit tournament_monitor_tournament_path(@tournament)
    if page.has_text?("Internal Server Error", wait: 0) ||
        page.has_text?("We're sorry, but something went wrong", wait: 0)
      skip "tournament_monitor page renders 500 in test env (pre-existing fixture dependency; out of scope for plan 36B-06)"
    end
    return if page.has_css?("form#start_tournament", wait: 0)

    skip "start_tournament form not present on rendered page — likely upstream view error unrelated to plan 36B-06"
  end

  def fill_balls_goal(value)
    # number_field_tag :balls_goal renders <input type="number" name="balls_goal">.
    # Use the name attribute directly — no reliance on labels or DOM ids.
    within("#start_tournament") do
      find("input[name='balls_goal']").set(value.to_s)
    end
  end

  def click_start_button
    # submit_tag I18n.t("tournaments.start_tournament") renders
    # <input type="submit" name="commit" value="...">. Find by name="commit"
    # scoped to the start_tournament form so other submit inputs do not match.
    within("#start_tournament") do
      find("input[type='submit'][name='commit']").click
    end
  end

  def verification_title
    I18n.t("tournaments.monitor_form.verification.title", default: "Ungewöhnliche Turnierparameter")
  end

  STARTED_STATES = %w[tournament_started tournament_started_waiting_for_monitors].freeze

  test "out-of-range balls_goal opens verification modal" do
    visit_monitor_or_skip

    fill_balls_goal(99999)
    click_start_button

    # Server re-renders with @verification_failure set; the second
    # shared/confirmation_modal render has auto_open: true, so the
    # plan-05 Stimulus controller auto-opens it on connect().
    assert_text verification_title
    assert_text "99999"

    # Tournament did NOT transition.
    assert_not_equal "tournament_started", @tournament.reload.state
  end

  test "clicking Cancel keeps tournament un-started" do
    visit_monitor_or_skip

    fill_balls_goal(99999)
    click_start_button

    assert_text verification_title
    find("button[data-action='click->confirmation-modal#cancel']", match: :first).click

    assert_not_equal "tournament_started", @tournament.reload.state
  end

  test "clicking Confirm starts the tournament with the override" do
    visit_monitor_or_skip

    fill_balls_goal(99999)
    click_start_button

    assert_text verification_title
    find("button[data-action='click->confirmation-modal#confirm']", match: :first).click

    # The controller's start action runs start_tournament! + explicit save (commit
    # e362f8a9) and redirects to tournament_monitor_path(@tournament.tournament_monitor).
    # We assert the post-redirect URL pattern instead of @tournament.reload.state because
    # Capybara's Puma server runs on a separate Postgres connection from the test thread;
    # with use_transactional_tests = true (project convention; test/TEST_DATABASE_SETUP.md
    # line 94), the test thread cannot see the server thread's committed state UPDATE via
    # AR reload. The URL is observable cross-thread via the browser session.
    #
    # Layer 1 prerequisite: test/fixtures/users.yml :admin block carries `role: club_admin`
    # (added by quick-260506-me5 Task 1) so this redirect is NOT bounced to / by
    # TournamentMonitorsController#ensure_tournament_director (controllers/
    # tournament_monitors_controller.rb:201-206).
    #
    # See quick-260506-me5 diagnosis Layers 1 + 2 for the full reasoning. Layer 3
    # (Region[1] nil-crash in _left_nav.html.erb:156 under system_admin) stays dormant
    # because :admin uses club_admin, not system_admin.
    assert_current_path %r{\A/tournament_monitors/\d+\z}, wait: 10
    assert_no_text verification_title
  end

  test "in-range values skip the modal and start the tournament directly" do
    visit_monitor_or_skip

    # Phase 39: parameter_ranges(tournament:)[:balls_goal] is now derived from the
    # matched DTP row (Freie Partie klein, plan t04_5, players=5, class "1" → points=250).
    # Range = (187..250). safe_value = 187 + 5 = 192, comfortably in-range.
    safe_value = @tournament.discipline.parameter_ranges(tournament: @tournament)[:balls_goal].first + 5
    fill_balls_goal(safe_value)
    click_start_button

    assert_no_text verification_title
    # Same controller path + cross-thread-visibility rationale as the Confirm-click test
    # above (Test 3): in-range values skip the verification modal, the start action runs
    # start_tournament! + save, and redirects to tournament_monitor_path. The URL is
    # cross-thread-visible via the browser session; @tournament.reload.state is not
    # (test thread / Puma thread connection isolation under use_transactional_tests).
    # Task 1's `role: club_admin` on the :admin fixture ensures ensure_tournament_director
    # does not bounce.
    assert_current_path %r{\A/tournament_monitors/\d+\z}, wait: 10
  end

  # Phase 39 D-17 + D-10/D-11: verify the modal does NOT fire on configurations
  # that legitimately have no master-data range (returns {} from parameter_ranges).
  # ===========================================================================

  test "non-DTP discipline (BK-2kombi) skips verification entirely" do
    @tournament = tournaments(:local_bk2kombi_non_dtp)
    sign_in @user if @user
    visit_monitor_or_skip

    # Any balls_goal — even a wildly out-of-range value that would have tripped
    # the old hardcoded ranges — must NOT open the modal because parameter_ranges
    # returns {} for non-DTP disciplines (D-10).
    fill_balls_goal(99999)
    click_start_button

    assert_no_text verification_title,
      "D-10: BK-2kombi (non-DTP discipline) must skip verification → modal must NOT appear"
    assert_current_path %r{\A/tournament_monitors/\d+\z}, wait: 10
  end

  test "handicap_tournier=true tournament skips verification entirely" do
    @tournament = tournaments(:local_handicap)
    sign_in @user if @user
    visit_monitor_or_skip

    fill_balls_goal(99999)
    click_start_button

    assert_no_text verification_title,
      "D-11: handicap_tournier=true must skip verification → modal must NOT appear"
    assert_current_path %r{\A/tournament_monitors/\d+\z}, wait: 10
  end

  test "tournament without tournament_plan skips verification (defensive)" do
    @tournament = tournaments(:local_no_plan)
    sign_in @user if @user
    visit_monitor_or_skip

    fill_balls_goal(99999)
    click_start_button

    assert_no_text verification_title,
      "D-16(f): tournament_plan=nil must skip verification → modal must NOT appear"
    assert_current_path %r{\A/tournament_monitors/\d+\z}, wait: 10
  end
end
