# frozen_string_literal: true

require "application_system_test_case"

# UI-06 D-20: Capybara system test for the shared confirmation modal (plan 36B-05).
# Asserts the three beats of the safety dialog:
#   1. clicking Reset opens the modal (+ Stimulus scope guard from 260506-i6h)
#   2. Cancel dismisses the modal and does not POST
#   3. Confirm POSTs to reset_tournament_path and the tournament state rewinds
#
# 260506-i6h tightening (2026-04-14 todo): visit_tournament_or_skip dropped its
# has_css? modal-presence skip (modal partial is now per-page rendered per
# commit 5ef81ab0) and converted its 500-error skip to a flunk so regressions
# fail loudly. ALL `[data-controller='confirmation-modal'].hidden` selectors
# rewritten to `[data-confirmation-modal-target='root'].hidden` because .hidden
# lives on the root target div, NOT on the controller-scope div (which uses
# style="display: contents;"). Prong A fix landed in
# test/fixtures/tournaments.yml :: local (tournament_plan: t04_5 + explicit
# organizer_id / season_id columns).
class TournamentResetConfirmationTest < ApplicationSystemTestCase
  setup do
    # sign_in is provided by Devise::Test::IntegrationHelpers, which is
    # already included in ApplicationSystemTestCase. Guard loudly so a
    # misconfigured test helper fails loudly instead of silently skipping.
    raise "sign_in helper required — include Devise::Test::IntegrationHelpers in ApplicationSystemTestCase" unless respond_to?(:sign_in)

    # Use the admin fixture — gates only need a signed-in user for
    # ApplicationController callbacks; the primary reset button is gated
    # solely on !tournament_started, not on User::PRIVILEGED.
    @user = users(:admin) rescue User.first
    sign_in @user if @user

    # Pick a tournament that is NOT started so the primary reset button renders.
    # The `local` fixture has state "registration" and no games → tournament_started
    # returns false (games.where("id >= MIN_ID").empty?).
    @tournament = tournaments(:local) rescue Tournament.where(state: "registration").first
    skip "no eligible non-started tournament fixture available" unless @tournament
  end

  # Per commit 5ef81ab0 the shared/confirmation_modal partial is rendered
  # per-page (always present in DOM), so the modal-presence skip from the
  # original implementation is dead code and was removed (260506-i6h Task 4).
  # The 500-error branch is preserved as a flunk (NOT skip) so any future
  # regression in the show partial fails LOUDLY instead of silently. Prong A
  # (tournament_plan FK + organizer/season FK rot) was fixed in
  # tournaments.yml :: local in this same quick task.
  def visit_tournament_or_skip
    visit tournament_path(@tournament)
    if page.has_text?("Internal Server Error", wait: 0) ||
       page.has_text?("We're sorry, but something went wrong", wait: 0)
      flunk "tournament show page rendered 500 — fixture or view regression. " \
            "Last known causes: (a) tournament_plan_id nil on tournaments(:local) " \
            "(tournament_monitor.html.erb:40); (b) organizer_id/season_id FK rot " \
            "from fixture-relation syntax (_show.html.erb:5). Both fixed in 260506-i6h."
    end
  end

  test "clicking reset opens the confirmation modal" do
    visit_tournament_or_skip

    # Stimulus scope guard (260506-i6h, per 2026-04-14 todo step 3): the trigger
    # button MUST live inside the same data-controller='confirmation-modal'
    # subtree as the modal it opens. This locks the per-page-render contract
    # (commit 5ef81ab0) — if a future refactor moves the modal partial to
    # layout-render-only, this assertion fails LOUDLY before the original
    # modal-open assertions.
    trigger = find("button[data-action*='confirmation-modal#open']", match: :first)
    modal_scope_present = trigger.evaluate_script(<<~JS)
      (function (el) {
        let n = el;
        while (n && n.nodeType === 1) {
          if (n.dataset && n.dataset.controller && n.dataset.controller.split(/\\s+/).includes('confirmation-modal')) {
            return true;
          }
          n = n.parentElement;
        }
        return false;
      })(this)
    JS
    assert modal_scope_present,
           "Reset trigger button MUST be inside a data-controller='confirmation-modal' subtree (per commit 5ef81ab0)"

    # Before any click, a confirmation-modal scope exists and its root target is hidden.
    # Note: .hidden lives on [data-confirmation-modal-target='root'] (the inner div),
    # NOT on [data-controller='confirmation-modal'] (the outer scope div, which uses
    # style="display: contents;" and never gets toggled).
    assert_selector "[data-controller='confirmation-modal']", visible: :all
    assert_selector "[data-confirmation-modal-target='root'].hidden", visible: :all

    # Click the primary reset trigger button.
    find("button[data-action='click->confirmation-modal#open'][data-confirmation-modal-form-id-param*='reset-tournament-form']", match: :first).click

    # Modal root target is now visible (hidden class gone from the per-page-rendered instance).
    assert_no_selector "[data-confirmation-modal-target='root'].hidden", visible: :all
    assert_text I18n.t("tournaments.show.reset_tournament_modal.title", default: "Turnier-Monitor zurücksetzen")
  end

  test "clicking Cancel dismisses the modal without POSTing" do
    visit_tournament_or_skip

    state_before = @tournament.reload.state
    find("button[data-action='click->confirmation-modal#open'][data-confirmation-modal-form-id-param*='reset-tournament-form']", match: :first).click

    find("button[data-action='click->confirmation-modal#cancel']").click

    # Modal is hidden again
    assert_selector "[data-confirmation-modal-target='root'].hidden", visible: :all

    # Tournament state is unchanged — no POST happened.
    assert_equal state_before, @tournament.reload.state
  end

  test "clicking Confirm submits the reset form" do
    visit_tournament_or_skip

    find("button[data-action='click->confirmation-modal#open'][data-confirmation-modal-form-id-param*='reset-tournament-form']", match: :first).click
    find("button[data-action='click->confirmation-modal#confirm']").click

    # Page redirects back to the tournament (TournamentsController#reset → redirect_to tournament_path)
    assert_current_path tournament_path(@tournament)

    # After reset_tmt_monitor! the tournament's state returns to new_tournament
    # (the initial AASM state after a full reset).
    assert_includes %w[new_tournament registration], @tournament.reload.state
  end
end
