---
status: diagnosed
trigger: "Phase 38.7 Gap-05 — tiebreak modal re-opens after winner pick + 'Mit Sieger bestätigen' click"
created: 2026-04-30T23:50:00Z
updated: 2026-04-30T23:55:00Z
---

## Current Focus

hypothesis: NONE OF THE 3 PRE-FILLED hypotheses. The actual root cause is a VIEW-level form-submission wiring bug.
test: read modal HTML + reflex flow + Rails dev log for the actual events when user clicks the button
expecting: a confirm_result reflex fire with `tiebreak_winner` param. INSTEAD: a plain HTTP GET form submission with no reflex involvement.
next_action: report ROOT CAUSE FOUND with file:line evidence

## Symptoms (immutable)

expected: After picking a tiebreak winner radio + clicking "Mit Sieger bestätigen", `game.data['tiebreak_winner']` is persisted, AASM transitions through `acknowledge_result!`, set is closed, match advances. No modal re-open.
actual: After clicking "Mit Sieger bestätigen", the page reloads (full HTTP GET) to `/table_monitors/<id>?tiebreak_winner=playerb` and the modal re-opens identically with the same tiebreak fieldset. NO reflex fires. NO winner is persisted. The only escape is the destructive "Spiel beenden" reflex.
errors: NO reflex fire is recorded in the log between the modal-open event (23:25:19) and the "Spiel beenden" event (23:25:30). Only a plain `Started GET "/table_monitors/50000002?tiebreak_winner=playerb"` at 23:25:23.
reproduction: BK-2 quick-game with `tiebreak_on_draw: true`, both players reach balls_goal in 1 inning each → modal opens with tiebreak fieldset → operator picks Sieger A or Sieger B → clicks green "Mit Sieger bestätigen" button.
started: 2026-04-30 (after gap-closure plans 38.7-09/10/11/12 fixed the original modal-rendering failure; this submit-loop is a NEW regression that was always present in Plan 06's view, but only became reachable once the modal began rendering correctly)

## Eliminated

- hypothesis: tiebreak_pick_pending? lacks short-circuit on resolved tiebreak (Hypothesis #1)
  evidence: result_recorder.rb:312-313 ALREADY has `return false if @tm.game.data["tiebreak_winner"].present?`. Predicate is correct. The predicate is never reached because the reflex never fires.
  timestamp: 2026-04-30T23:55:00Z

- hypothesis: bk2_kombi_tiebreak_auto_detect! re-fires every call without guard (Hypothesis #2)
  evidence: result_recorder.rb:344 has the idempotency guard `return if @tm.game&.data&.[]("tiebreak_required") == true`. Plus the helper short-circuits unless `free_game_form == "bk2_kombi"`, but the user's TR-B test was free_game_form="bk_2" (single BK-2 quick-game, NOT bk2_kombi). The auto-detect helper does not run at all in this TR-B path. Irrelevant.
  timestamp: 2026-04-30T23:55:00Z

- hypothesis: AASM/reflex submit path doesn't actually advance state (Hypothesis #3)
  evidence: The AASM guard logic is correct AND the reflex's confirm_result method correctly persists `tiebreak_winner` via `deep_merge_data!` and calls `evaluate_result` (game_protocol_reflex.rb:121-153). The handler is fine. But the reflex NEVER FIRES — the browser's form submission shortcuts the entire reflex stack.
  timestamp: 2026-04-30T23:55:00Z

## Evidence

- timestamp: 2026-04-30T23:55:00Z (development.log line 5159430)
  checked: log line for the moment the tiebreak modal opens (TR-B reproduction)
  found: TableMonitor 50000002, free_game_form="bk_2", playera=70/70 in 1 inning, playerb=70/70 in 1 inning. result_recorder.rb:431 fires `current_element = tiebreak_pick_pending? ? "tiebreak_winner_choice" : "confirm_result"` and persists `current_element=tiebreak_winner_choice` correctly.
  implication: The marker switch and tiebreak detection work as designed. The modal renders with the radio fieldset.

- timestamp: 2026-04-30T23:55:00Z (development.log line 5159819)
  checked: log entries between modal-open (23:25:19) and "Spiel beenden" (23:25:30) for any reflex/HTTP activity
  found: Exactly ONE event: `Started GET "/table_monitors/50000002?tiebreak_winner=playerb" for 127.0.0.1 at 2026-04-30 23:25:23 +0200`. NO `StimulusReflex::Channel#receive`. NO `🎯 GameProtocolReflex#confirm_result`. The button click did NOT invoke the reflex — it triggered a plain browser form-submit GET request.
  implication: SMOKING GUN. The form is being submitted via the browser's default HTML form-submission mechanism (no method/action defined, so it defaults to GET against the current URL). StimulusReflex never sees the event.

- timestamp: 2026-04-30T23:55:00Z (file: app/views/table_monitors/_game_protocol_modal.html.erb:172-200, 209-218)
  checked: How is the form wired vs how is the submit button wired?
  found:
    Line 173: `<form id="tiebreak-form-<id>" class="..." data-reflex-permanent>` — note: NO `data-reflex` attribute, NO `action=`, NO `method=`. Only `data-reflex-permanent` (which is unrelated; it's a CableReady/StimulusReflex hint to preserve form state across morphs).
    Line 200: `</form>` — the form is closed BEFORE the action footer block.
    Line 212-218 (OUTSIDE the form): `<button type="submit" form="tiebreak-form-<id>" data-reflex="submit->GameProtocolReflex#confirm_result" data-id="...">`. The button is OUTSIDE the form element but linked via `form="tiebreak-form-<id>"` (HTML5 form-association attribute).
  implication: When the user clicks the button:
    1. Browser fires a `submit` event on the FORM (id `tiebreak-form-<id>`) — NOT on the button.
    2. StimulusReflex listens for `submit->` events on the element WHERE the data-reflex attribute lives. The form has NO data-reflex; the button has `data-reflex="submit->..."` but the button never fires a submit event (forms do).
    3. The form has no `action=` and no `method=`, so the browser defaults to GET against the current URL with the form's form-data as a query string.
    4. The browser performs the GET → page reloads → modal re-renders with the same `current_element=tiebreak_winner_choice` (which the reflex never had a chance to clear) → user sees the modal "re-open" identically.
    The reflex's `confirm_result` method is never reached, the AASM `:acknowledge_result` event never fires, the predicate guards are irrelevant — the bug happens 100% in the form-submission wiring, BEFORE any Ruby code runs.

- timestamp: 2026-04-30T23:55:00Z (file: app/reflexes/game_protocol_reflex.rb:116-154)
  checked: Reflex handler's confirm_result logic (the one that would run if the reflex fired)
  found: When `current_element=="tiebreak_winner_choice"` AND `params[:tiebreak_winner] in ['playera','playerb']`, persists via `deep_merge_data!`, then sets panel_state="pointer_mode", calls `evaluate_result` (which goes through ResultRecorder → marker switch → the predicate now sees winner present → returns false → set closes via the `set_over` branch's `acknowledge_result!`). The handler IS correct — it's just never called.
  implication: Once the form/button wiring is fixed (so the reflex actually fires with the form-data), the rest of the chain WILL close the set. The downstream code is good.

- timestamp: 2026-04-30T23:55:00Z (development.log line 5159819 → 5159889)
  checked: What happened after the GET reload
  found: 23:25:23 GET → page renders modal again (current_element still tiebreak_winner_choice) → 23:25:30 user clicks "Spiel beenden" → escape via destructive terminate_game.
  implication: User perceives an infinite loop. The escape via "Spiel beenden" works because that button has `data-reflex="click->TableMonitorReflex#terminate_game"` (a normal click reflex, not bound to the broken form).

## Resolution

root_cause: |
  The `<form id="tiebreak-form-<id>">` in `app/views/table_monitors/_game_protocol_modal.html.erb:173-200` has NO `data-reflex` attribute and NO `action=`/`method=` attributes. The submit button at line 212-218 carries `data-reflex="submit->GameProtocolReflex#confirm_result"` but `submit` events fire on FORMS, not on buttons — so StimulusReflex never observes the event. The browser's default form-submit behavior triggers a plain HTTP GET to the current URL with `tiebreak_winner=...` in the query string, which reloads the show page; since `current_element=tiebreak_winner_choice` is still persisted on the TM (no reflex ran to clear it), the modal re-renders identically. None of the predicate / auto-detect / AASM-guard logic is reachable from this code path.

fix:
  - PRIMARY: move `data-reflex="submit->GameProtocolReflex#confirm_result"` and `data-id="<%= table_monitor.id %>"` from the BUTTON (line 215-216) to the FORM element at line 173-175. Keep the button as a plain `type="submit"` (so HTML5 'required' radio validation still runs). The `data-reflex-permanent` on the form may stay but is unrelated to the fix.
  - DEFENSIVE: add `action="javascript:void(0)"` (or `onsubmit="return false"`) to the form so that even if StimulusReflex misses the event for any reason, the browser does NOT do a fallback GET reload — the user gets a no-op rather than a confusing modal re-render.
  - Both changes are local to `app/views/table_monitors/_game_protocol_modal.html.erb` lines 172-218. NO reflex code changes required, NO predicate code changes required, NO AASM guard changes required.

verification: pending — gap-closure plan should ship the view fix + a system test that simulates the form submission + verifies tiebreak_winner persists + AASM transitions to final_set_score (the existing reflex unit tests in test/reflexes/game_protocol_reflex_test.rb DO exercise the handler path correctly, but they call the handler directly — they do NOT exercise the view-to-reflex wiring, which is exactly the gap).

files_changed: []  # diagnose-only mode
