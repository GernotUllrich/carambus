---
status: investigating
trigger: "After filling out the parameter form in the tournament_monitor wizard, clicking start tournament does nothing"
created: 2026-04-14T20:15:00+0200
updated: 2026-04-14T20:30:00+0200
---

## Current Focus

hypothesis: ROOT CAUSE CONFIRMED — Turbo Stream / HTML response mismatch in the 36B-06 parameter verification gate.
test: Confirmed via server log analysis: server IS hit (200 OK), but re-renders HTML into a TURBO_STREAM request.
expecting: N/A — root cause found.
next_action: Return diagnosis

## Symptoms

expected: After filling out parameter form and clicking start, tournament transitions AASM state and UI updates
actual: Nothing happens — no flash, no page update, no visible error
errors: None visible to user. Server log at 20:03:34: server returns 200 OK with full HTML page, but Turbo silently discards non-stream response.
reproduction:
  1. Navigate to http://0.0.0.0:3007/tournaments/17411/tournament_monitor
  2. Fill out parameter form
  3. Click start button
  4. Nothing happens
started: Regression from Phase 36B-06 (parameter verification gate added to #start action)

## Eliminated

- hypothesis: Client-side JS failure — button click not reaching server at all
  evidence: Server log at line 4249639 shows "Started POST /tournaments/17411/start" at 20:03:34 and again at 20:03:44. Two consecutive start-button clicks, both reaching the server.
  timestamp: 2026-04-14T20:28:00+0200

- hypothesis: Stimulus controller intercept (confirmation_modal, tooltip) blocking the form submit
  evidence: Server receives the POST — no client-side JS blocking. The form submits correctly.
  timestamp: 2026-04-14T20:28:00+0200

## Evidence

- timestamp: 2026-04-14T20:14:00+0200
  checked: Tail of /Users/gullrich/DEV/carambus/carambus_bcw/log/development.log (last 200 lines)
  found: Only WebSocket keepalive activity, no POST.
  implication: Led to incorrect hypothesis of client-side failure. Log tail was from AFTER the click, not during.

- timestamp: 2026-04-14T20:26:00+0200
  checked: Full log search for "TournamentsController#start" and "17411/start"
  found: Lines 4249639-4249768. At 20:03:34 POST /tournaments/17411/start received. Processing as TURBO_STREAM. Renders tournament_monitor.html.erb. Completed 200 OK.
  implication: Server IS hit. Response is a full HTML page rendered into a Turbo Stream request.

- timestamp: 2026-04-14T20:27:00+0200
  checked: tournament_monitor.html.erb line 315 and controller start action
  found: `render :tournament_monitor and return` — plain render, no respond_to block, no format.turbo_stream handling.
  implication: When the verification gate fires (balls_goal=100, innings_goal=20 out of range for discipline 34), the controller renders a full HTML page. Turbo submitted the form as TURBO_STREAM and expects either a Turbo Stream response or a redirect (3xx). A 200 HTML body is silently discarded by Turbo — the DOM does not update.

- timestamp: 2026-04-14T20:28:00+0200
  checked: Log line 4249776 — second POST at 20:03:44
  found: Same params, same behavior. parameter_verification_confirmed="0", exact same result.
  implication: User clicked start twice; same silent discard both times. Confirms the re-render path, not a one-off.

## Resolution

root_cause: |
  The 36B-06 parameter verification gate (commit 83093498) added `render :tournament_monitor and return`
  inside TournamentsController#start when out-of-range parameters are detected. However, the start form
  uses a standard Turbo-enhanced form submission (no `data-turbo="false"`), so Rails/Turbo sends the
  POST request with Accept: text/vnd.turbo-stream.html. When the controller responds with a plain 200
  HTML re-render (not a redirect or a Turbo Stream response), Turbo silently discards the response body
  — the DOM doesn't update, no flash appears, and from the user's perspective nothing happens.
  
  For tournament 17411 (discipline 34 = "Dreiband klein"), balls_goal=100 and innings_goal=20 fall
  outside the configured parameter_ranges, so every click of the start button hits this code path.
  The intended behavior (showing a confirmation modal with the out-of-range values) never appears.

fix: |
  Three possible approaches:
  1. (Simplest) Add `data: { turbo: false }` to the start_tournament form_tag so it submits as a
     regular HTML form POST (not TURBO_STREAM). The verification failure re-render would then display
     normally in the browser. Tradeoff: loses Turbo's speed benefit on the happy path.
  2. (Clean) Wrap the verification failure render in `respond_to do |format| / format.html { render :tournament_monitor } / format.turbo_stream { render turbo_stream: turbo_stream.replace("main-content", partial: "tournaments/tournament_monitor") } end`.
     Requires adding an id target in the layout.
  3. (Best UX) Replace the server-side re-render with a redirect: on verification failure, store
     the failure payload in flash/session and redirect_to tournament_monitor_tournament_path(@tournament).
     The GET re-render of tournament_monitor reads the flash and shows the orange banner + modal.
     Cleanest because it follows PRG (Post/Redirect/Get) pattern — avoids double-submit and works
     with any Turbo/HTML client.

verification:
files_changed: []
