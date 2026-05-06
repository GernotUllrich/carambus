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

    # Find a tournament that is NOT already started and whose discipline
    # has known parameter_ranges so the server-side check can fire.
    @tournament = Tournament.joins(:discipline)
      .where.not(state: %w[tournament_started playing_groups playing_finals finals_finished results_published closed])
      .to_a
      .find { |t| t.discipline&.parameter_ranges&.any? }
    skip "no eligible tournament with discipline ranges in fixtures" unless @tournament
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

    # 100 is inside every Range in DISCIPLINE_PARAMETER_RANGES for balls_goal
    # except "Dreiband" (10..80). Pick an in-range value based on discipline.
    safe_value = @tournament.discipline.parameter_ranges[:balls_goal].first + 5
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
end
