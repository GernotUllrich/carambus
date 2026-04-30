# frozen_string_literal: true

require "test_helper"

# Phase 38.7 Plan 13 — Gap-05 view-wiring regression suite.
#
# Closes the gap left by Plan 06's tests (T1-T5 in
# test/reflexes/game_protocol_reflex_test.rb) and Plan 08's system tests
# (TR-A/TR-B/TR-Ctl/TR-Sec in test/system/tiebreak_test.rb): NEITHER
# exercises the actual view→DOM→reflex chain. They invoke the reflex
# directly via .allocate + define_singleton_method, bypassing the
# form-submit-event observability that StimulusReflex depends on.
#
# Gap-05 root cause (debug session 2026-04-30, see
# .planning/debug/tiebreak-submit-loop.md): the <form> in
# _game_protocol_modal.html.erb had no data-reflex; the data-reflex was on
# the <button>, but submit events fire on FORMS, not buttons. The browser
# silently fell through to a default GET-reload in an infinite loop until
# the operator hit "Spiel beenden" (destructive abort).
#
# This suite locks the contract at TWO levels:
#
#   1. Render-level (G1, G2, G3): assert the rendered HTML attributes.
#      Catches the wiring bug as soon as it re-appears, without needing
#      a full browser/StimulusReflex roundtrip.
#
#   2. GET-fallback (G4): assert that a plain HTTP GET with
#      ?tiebreak_winner=... does NOT advance state. Defense-in-depth
#      against the smoking-gun in the dev log: should the form
#      action="javascript:void(0)" defense ever be removed, this test
#      catches a state-advance regression at the request level.
#
# Together these close the test gap that allowed the original bug to
# ship despite GREEN unit + system tests.
class TiebreakModalFormWiringTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tm = table_monitors(:one)
    @game = Game.create!(
      data: {"tiebreak_required" => true},
      group_no: 1, seqno: 1, table_no: 1
    )
    @game_created_by_test = true

    # Tied karambol scores so tiebreak_pending_block? would hold (matches
    # the canonical TR-A reproduction in test/system/tiebreak_test.rb).
    @tm.update!(
      data: {
        "free_game_form" => "karambol",
        "playera" => {"discipline" => "Dreiband", "result" => 80, "innings" => 30,
                      "balls_goal" => 80, "innings_redo_list" => [0]},
        "playerb" => {"discipline" => "Dreiband", "result" => 80, "innings" => 30,
                      "balls_goal" => 80, "innings_redo_list" => [0]},
        "innings_goal" => 30,
        "allow_follow_up" => false
      }
    )
    @tm.update_columns(
      game_id: @game.id,
      panel_state: "protocol_final",
      current_element: "tiebreak_winner_choice"
    )
    @tm.reload
  end

  teardown do
    if @game_created_by_test && @game&.persisted?
      @tm.update_columns(
        game_id: nil, state: "new",
        panel_state: "pointer_mode",
        current_element: "pointer_mode"
      )
      @tm.update!(data: {})
      @game.reload.destroy
    end
  end

  # ---------------------------------------------------------------
  # G1 (Gap-05): the FORM element carries data-reflex submit binding
  # so StimulusReflex observes the actual submit event.
  # ---------------------------------------------------------------
  test "G1 (Gap-05): form#tiebreak-form-<id> carries data-reflex='submit->GameProtocolReflex#confirm_result'" do
    html = ApplicationController.render(
      partial: "table_monitors/game_protocol_modal",
      locals: {table_monitor: @tm, full_screen: true, modal_hidden: false}
    )
    doc = Nokogiri::HTML.fragment(html)

    form = doc.at_css("form#tiebreak-form-#{@tm.id}")
    assert form, "Gap-05: tiebreak form must render in current_element=tiebreak_winner_choice state"

    assert_equal "submit->GameProtocolReflex#confirm_result", form["data-reflex"],
      "Gap-05: data-reflex='submit->...' MUST be on the <form> (not the <button>) " \
      "because browsers fire submit events on forms"

    assert_equal @tm.id.to_s, form["data-id"],
      "Gap-05: data-id MUST be on the <form> alongside data-reflex so " \
      "GameProtocolReflex#load_table_monitor can find the TableMonitor via element.dataset['id']"

    assert_equal "javascript:void(0)", form["action"],
      "Gap-05: form action='javascript:void(0)' is the no-op fallback — " \
      "if StimulusReflex misses the submit event for any reason, the " \
      "browser must NOT fall through to a default GET-reload " \
      "(the smoking-gun behavior of the original bug)"
  end

  # ---------------------------------------------------------------
  # G2 (Gap-05): the submit BUTTON does NOT carry data-reflex —
  # regression guard against re-introducing the bug.
  # ---------------------------------------------------------------
  test "G2 (Gap-05): tiebreak submit button has NO data-reflex (regression guard)" do
    html = ApplicationController.render(
      partial: "table_monitors/game_protocol_modal",
      locals: {table_monitor: @tm, full_screen: true, modal_hidden: false}
    )
    doc = Nokogiri::HTML.fragment(html)

    button = doc.at_css("button[type='submit'][form='tiebreak-form-#{@tm.id}']")
    assert button, "Tiebreak submit button must render"

    assert_nil button["data-reflex"],
      "Gap-05 regression guard: the submit button must NOT carry data-reflex — " \
      "this attribute belongs on the <form> (where submit events actually fire). " \
      "If this fails, the Plan 06 bug has been re-introduced."

    assert_nil button["data-id"],
      "Gap-05 regression guard: data-id is on the form (where the data-reflex is); " \
      "the button does not need it"

    # Submit semantics MUST be preserved: the button's type=submit + form=...
    # association is what triggers HTML5 'required' validation on the
    # radio inputs and dispatches the submit event to the form.
    assert_equal "submit", button["type"],
      "Gap-05: button must remain type=submit (HTML5 'required' radio validation runs on submit, not click)"

    assert_equal "tiebreak-form-#{@tm.id}", button["form"],
      "Gap-05: button form='tiebreak-form-<id>' association must be preserved " \
      "so it triggers the form's submit event when clicked"
  end

  # ---------------------------------------------------------------
  # G3 (Gap-05): legacy non-tiebreak path is UNCHANGED — click-bound
  # data-reflex on the button is correct (click events fire on buttons).
  # ---------------------------------------------------------------
  test "G3 (Gap-05): legacy non-tiebreak path keeps click->confirm_result on the button (regression guard)" do
    # Switch to legacy path: current_element=confirm_result (NOT tiebreak_winner_choice)
    @tm.update_columns(current_element: "confirm_result")
    @tm.reload

    html = ApplicationController.render(
      partial: "table_monitors/game_protocol_modal",
      locals: {table_monitor: @tm, full_screen: true, modal_hidden: false}
    )
    doc = Nokogiri::HTML.fragment(html)

    # Legacy path must NOT render the tiebreak form.
    form = doc.at_css("form#tiebreak-form-#{@tm.id}")
    assert_nil form,
      "Legacy non-tiebreak path must NOT render the tiebreak form (only the legacy button)"

    # The legacy 'Ergebnis bestätigen' button must be present with click-bound reflex.
    legacy_button = doc.css("button").find { |b| b.text.include?("Ergebnis bestätigen") }
    assert legacy_button,
      "Legacy 'Ergebnis bestätigen' button must render in non-tiebreak path"

    assert_equal "click->GameProtocolReflex#confirm_result", legacy_button["data-reflex"],
      "Legacy path: click->confirm_result on the button is correct " \
      "(click events fire on buttons; this is the path the bug did NOT affect)"

    assert_equal @tm.id.to_s, legacy_button["data-id"],
      "Legacy button must have data-id for load_table_monitor"
  end

  # ---------------------------------------------------------------
  # G4 (Gap-05): GET fallback no-op contract.
  #
  # The bug's smoking gun was 'Started GET /table_monitors/<id>?tiebreak_winner=playerb'
  # in the dev log — a plain HTTP GET that reloaded the page without any
  # state advance, leaving current_element=tiebreak_winner_choice intact
  # so the modal re-rendered identically (infinite loop).
  #
  # This test locks the invariant: even if such a GET reaches the
  # controller (e.g., if Task 1's action='javascript:void(0)' defense
  # ever gets removed), the controller must NOT advance state from a
  # plain GET. game.data['tiebreak_winner'] stays nil; current_element
  # stays tiebreak_winner_choice. The state advance must come ONLY from
  # the StimulusReflex roundtrip via Action Cable.
  # ---------------------------------------------------------------
  test "G4 (Gap-05): plain GET /table_monitors/<id>?tiebreak_winner=playera does NOT advance state" do
    # If TableMonitor#show requires auth, sign in. If it's public, this
    # is a no-op — Devise's sign_in is idempotent on already-public actions.
    # The :club_admin user is the standard fixture used by other controller
    # tests in this project.
    sign_in users(:club_admin) if users(:club_admin).present?

    # Snapshot pre-GET state.
    pre_current_element = @tm.current_element
    pre_panel_state = @tm.panel_state
    pre_tiebreak_winner = @game.data["tiebreak_winner"]
    assert_equal "tiebreak_winner_choice", pre_current_element, "Precondition: marker is tiebreak_winner_choice"
    assert_nil pre_tiebreak_winner, "Precondition: no winner persisted yet"

    # Simulate the smoking-gun GET. This is what the broken view did
    # silently via browser default form-submission. Even if the
    # action='javascript:void(0)' defense in Task 1 ever regresses, the
    # controller MUST NOT advance state from a plain GET.
    get table_monitor_url(@tm), params: {tiebreak_winner: "playera"}

    # Response must succeed (200) or redirect (302). Either is acceptable
    # — the assertion is on STATE, not response code.
    assert_includes [200, 302], response.status,
      "show action must respond normally (200 or 302) to the probe GET"

    # Reload and assert state is UNCHANGED.
    @tm.reload
    @game.reload

    assert_equal pre_current_element, @tm.current_element,
      "Gap-05 invariant: plain GET must NOT advance current_element from tiebreak_winner_choice"

    assert_equal pre_panel_state, @tm.panel_state,
      "Gap-05 invariant: plain GET must NOT change panel_state from protocol_final"

    assert_nil @game.data["tiebreak_winner"],
      "Gap-05 invariant: plain GET with ?tiebreak_winner=playera must NOT persist game.data['tiebreak_winner']. " \
      "State advance MUST come ONLY from the StimulusReflex roundtrip via Action Cable, " \
      "never from a query-string-only GET. This is the audit-trail closure of the " \
      "smoking-gun GET in development.log line ~5159819 (2026-04-30T23:25:23)."
  end
end
